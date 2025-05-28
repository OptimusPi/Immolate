"""
Application Controller - Handles interactions between models and views
"""
import os
import random
import time
from tkinter import messagebox

class ApplicationController:
    """Controller class to coordinate between models and views"""
    
    def __init__(self, config_model, search_model, database_model):
        """Initialize controller with models"""
        self.config_model = config_model
        self.search_model = search_model
        self.database_model = database_model
        self.current_view = None
        self.update_timer_id = None
        self.pending_results = None
        self.pending_headers = None
        self.update_debounce_ms = 1000  # Update UI at most every second
        
        # Set up callbacks for the search model
        self.search_model.set_callbacks(
            results_callback=self._on_search_results,
            console_callback=self._on_console_output,
            process_finished_callback=self._on_search_completed
        )
    
    def register_view(self, view):
        """Register the main view for callbacks"""
        self.current_view = view
    
    # Config management methods
    def load_config(self, file_path=None):
        """Load configuration from file"""
        if file_path is None:
            return False
            
        success = self.config_model.load_config_from_path(file_path)
        if success and self.current_view:
            # Update the view with the loaded config
            self.current_view.update_config_display()
            
            # Connect to the database for this config
            self.database_model.connect(file_path)
            self.refresh_results()
            
        return success
    
    def save_config(self, file_path=None):
        """Save current configuration to file"""
        if not self.config_model.config_name:
            if self.current_view:
                messagebox.showerror("Error", "Please enter a configuration name before saving.")
            return False
            
        if not self.config_model.needs_list and not self.config_model.wants_list:
            if self.current_view:
                messagebox.showerror("Error", "Please add at least one Need or Want before saving.")
            return False
        
        success, result = self.config_model.save_config(file_path)
        if success and self.current_view:
            self.current_view.set_status(f"Configuration saved: {result}")
        elif not success and self.current_view:
            messagebox.showerror("Error", f"Failed to save configuration: {result}")
        
        return success
    
    def get_config_files(self):
        """Get list of available configuration files"""
        return self.config_model.get_config_files()
    
    def get_config_name(self):
        """Get current configuration name"""
        return self.config_model.config_name
    
    def set_config_name(self, name):
        """Set configuration name"""
        self.config_model.config_name = name
        self.config_model.config_modified = True
    
    # Criteria management
    def add_need(self, need_data):
        """Add a need to the configuration"""
        success = self.config_model.add_need(need_data)
        if success and self.current_view:
            self.current_view.update_criteria_display()
        return success
    
    def add_want(self, want_data):
        """Add a want to the configuration"""
        success = self.config_model.add_want(want_data)
        if success and self.current_view:
            self.current_view.update_criteria_display()
        return success
    
    def remove_criterion(self, index):
        """Remove a criterion (need or want) by index"""
        # Determine if this is a need or a want based on index
        needs_count = len(self.config_model.needs_list)
        if index < needs_count:
            success = self.config_model.remove_need(index)
        else:
            success = self.config_model.remove_want(index - needs_count)
            
        if success and self.current_view:
            self.current_view.update_criteria_display()
        return success
    
    def clear_all_criteria(self):
        """Clear all needs and wants"""
        self.config_model.clear_all_criteria()
        if self.current_view:
            self.current_view.update_criteria_display()
        return True
    
    # Search management
    def run_search(self):  # Renamed from start_search
        """Start the search process"""
        if self.search_model.has_active_searches():
            # If there's already a search running, stop it instead
            return self.stop_search()
        # Ensure we have a valid config path (save if needed)
        config_path = self.config_model.get_command_config_path()
        if not config_path:
            if self.current_view:
                messagebox.showerror("Error", "Failed to prepare configuration for search.")
            return False
        # Ensure DuckDB database exists for this config
        db_path = self.database_model.get_db_path_from_config(config_path)
        if not os.path.exists(db_path):
            self.database_model.connect(config_path)
            self.database_model.close()
        # Connect to the database
        self.database_model.connect(config_path)        # Start the search
        success = self.search_model.start_search(
            config_path=config_path,
            starting_seed=self.config_model.starting_seed,
            thread_groups=self.config_model.thread_groups,
            number_of_seeds=self.config_model.number_of_seeds,
            db_model=self.database_model,
            cutoff=self.config_model.cutoff,  # Pass cutoff
            gpu_batch=self.config_model.gpu_batch,  # Pass gpu_batch
            template=self.config_model.template  # Pass template
        )
        # Update UI state if successful
        if success and self.current_view:
            self.current_view.set_search_running(True)
        return success
    
    def stop_search(self):
        """Stop any active search processes"""
        success = self.search_model.stop_all_searches()
        if success and self.current_view:
            self.current_view.set_search_running(False)
            self.current_view.write_to_console("--- Search Stopped ---\n")
        return success
    
    # Database and results management
    def refresh_results(self):
        """Refresh results from the database"""
        df = self.database_model.get_dataframe()
        if df is not None and self.current_view:
            self.current_view.update_results_table(df)
        return df is not None
    
    # Callbacks for the search model
    def _on_search_results(self, header_columns, result_rows):  # header_columns and result_rows are now None
        """Callback for when search results are available (signals to refresh from DB)"""
        if self.current_view:
            # Cancel any pending update
            if self.update_timer_id:
                self.current_view.root.after_cancel(self.update_timer_id)
            
            # Schedule a new update (which will now just call refresh_results)
            self.update_timer_id = self.current_view.root.after(
                self.update_debounce_ms, self._process_pending_results)
    
    def _process_pending_results(self):
        """Process pending results after debounce period (now just refreshes from DB)"""
        # Reset the timer ID
        self.update_timer_id = None
        
        # Refresh results directly from the database
        self.refresh_results()
        
        # Clear any potentially lingering pending results (though they shouldn't be set anymore)
        self.pending_results = None
        self.pending_headers = None
    
    def _on_console_output(self, line):
        """Callback for when there's output to the console"""
        if self.current_view:
            # Check if this is a status message
            if line.startswith("STATUS:"):
                # Extract the status message and set it in the status bar
                status_message = line[7:].strip()  # Remove "STATUS:" prefix
                
                # Format time display - convert seconds to days, hours, minutes, seconds
                import re
                
                def format_time(match):
                    seconds = float(match.group(1))
                    days, remainder = divmod(seconds, 86400)  # 86400 seconds in a day
                    hours, remainder = divmod(remainder, 3600)
                    minutes, seconds = divmod(remainder, 60)
                    
                    if days > 0:
                        return f"{int(days)}d {int(hours)}h {int(minutes)}m {int(seconds)}s"
                    elif hours > 0:
                        return f"{int(hours)}h {int(minutes)}m {int(seconds)}s"
                    elif minutes > 0:
                        return f"{int(minutes)}m {int(seconds)}s"
                    else:
                        return f"{int(seconds)}s"
                
                # Replace time values in both elapsed and remaining time sections
                status_message = re.sub(r"Elapsed time: (\d+\.\d+) seconds", 
                                       lambda m: f"Elapsed time: {format_time(m)}", status_message)
                status_message = re.sub(r"Estimated remaining time: (\d+\.\d+) seconds", 
                                       lambda m: f"Estimated remaining time: {format_time(m)}", status_message)
                
                # Check if this is a metrics message (contains clock emoji)
                if "⏱️" in status_message:
                    # Split into two parts: status and metrics
                    parts = status_message.split("⏱️")
                    if len(parts) == 2:
                        # Set the main status as the first part
                        self.current_view.set_status(parts[0].strip())
                        # Set the metrics as the second part with the clock emoji
                        self.current_view.set_metrics(f"⏱️{parts[1].strip()}")
                    else:
                        self.current_view.set_status(status_message)
                else:
                    # Regular status message
                    self.current_view.set_status(status_message)
            else:
                # Regular console output
                self.current_view.write_to_console(line)
    
    def _on_search_completed(self):
        """Callback for when a search process completes"""
        # Ensure one final refresh from the database
        self.refresh_results()
        if self.current_view:
            self.current_view.write_to_console("--- Search Complete ---\n")
            self.current_view.set_search_running(False)
    
    # User preference methods
    def get_setting(self, key, default=None):
        """Get a user setting value"""
        # Map settings to config_model properties
        settings_map = {
            'thread_groups': 'thread_groups',
            'starting_seed': 'starting_seed',
            'number_of_seeds': 'number_of_seeds',
            'deck': 'deck',
            'stake': 'stake',
            'cutoff': 'cutoff',
            'gpu_batch': 'gpu_batch',
            'template': 'template'
        }
        
        if key in settings_map:
            return getattr(self.config_model, settings_map[key], default)
        return default
    
    def set_setting(self, key, value):
        """Set a user setting value"""
        # Map settings to config_model properties
        settings_map = {
            'thread_groups': 'thread_groups',
            'starting_seed': 'starting_seed',
            'number_of_seeds': 'number_of_seeds',
            'deck': 'deck',
            'stake': 'stake',
            'cutoff': 'cutoff',
            'gpu_batch': 'gpu_batch',
            'template': 'template'
        }
        
        if key in settings_map:
            setattr(self.config_model, settings_map[key], value)
            self.config_model.config_modified = True
            self.config_model.save_user_conf()
            return True
        return False
    
    # Clean up resources
    def cleanup(self):
        """Clean up resources before application exit"""
        # Stop any active searches
        self.search_model.stop_all_searches()
        
        # Close database connections
        self.database_model.close()
        
        # Save user preferences
        self.config_model.save_user_conf()
        
        # Cancel any pending updates
        if self.update_timer_id and self.current_view:
            self.current_view.root.after_cancel(self.update_timer_id)
        
        return True