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
    
    def randomize_criteria(self):
        """Generate random criteria"""
        # Clear existing criteria
        self.config_model.clear_all_criteria()
        
        # Categories with weights favoring jokers
        categories = ["Jokers", "Jokers", "Jokers", "Tarots", "Spectrals", "Tags", "Vouchers"]
        
        # Get available items (will need to be provided from the view or a data model)
        items_by_category = self.current_view.get_available_items() if self.current_view else {}
        if not items_by_category:
            return False
        
        # Select random number of items (1-10)
        num_items = random.randint(1, 10)
        
        # Ensure at least one need
        need_count = random.randint(1, min(3, num_items))
        want_count = num_items - need_count
        
        # Add random needs
        for i in range(need_count):
            category = random.choice(categories)
            if category in items_by_category and items_by_category[category]:
                selected_item = random.choice(items_by_category[category])
                result = {
                    "value": selected_item.replace(" ", "_"),
                    "desireByAnte": random.randint(1, 8)
                }
                
                # Add random edition for jokers with 30% chance
                if category == "Jokers" and random.random() < 0.3:
                    editions = ["Foil", "Holographic", "Polychrome", "Negative"]
                    result["jokeredition"] = random.choice(editions)
                
                self.config_model.add_need(result)
        
        # Add random wants
        for i in range(want_count):
            category = random.choice(categories)
            if category in items_by_category and items_by_category[category]:
                selected_item = random.choice(items_by_category[category])
                result = {
                    "value": selected_item.replace(" ", "_"),
                    "desireByAnte": 8
                }
                
                # Add random edition for jokers with 30% chance
                if category == "Jokers" and random.random() < 0.3:
                    editions = ["Foil", "Holographic", "Polychrome", "Negative"]
                    result["jokeredition"] = random.choice(editions)
                
                self.config_model.add_want(result)
        
        # Also randomly select a deck and stake
        if "Decks" in items_by_category and items_by_category["Decks"]:
            self.config_model.deck = random.choice(items_by_category["Decks"])
        if "Stakes" in items_by_category and items_by_category["Stakes"]:
            self.config_model.stake = random.choice(items_by_category["Stakes"])
        
        # Set a random name for the configuration
        adjectives = ["Spicy", "Lucky", "Glorious", "Mysterious", "Powerful", "Chaotic", "Epic", "Golden", "Legendary", "Magical"]
        nouns = ["Fortune", "Destiny", "Victory", "Adventure", "Jackpot", "Treasure", "Poker", "Champion", "Joker", "Triumph"]
        self.config_model.config_name = f"{random.choice(adjectives)}{random.choice(nouns)}"
        
        # Update the view
        if self.current_view:
            self.current_view.update_config_display()
            self.current_view.update_criteria_display()
        
        return True
    
    # Search management
    def start_search(self):
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
        self.database_model.connect(config_path)
        # Start the search
        success = self.search_model.start_search(
            config_path=config_path,
            starting_seed=self.config_model.starting_seed,
            thread_groups=self.config_model.thread_groups,
            number_of_seeds=self.config_model.number_of_seeds,
            db_model=self.database_model
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
    def _on_search_results(self, header_columns, result_rows):
        """Callback for when search results are available"""
        if self.current_view:
            import pandas as pd
            from ..utils.game_data import get_display_name
            def clean_col(col):
                if col.startswith('Need(') and col.endswith(')'):
                    return get_display_name(col[5:-1])
                if col.startswith('Want(') and col.endswith(')'):
                    return get_display_name(col[5:-1])
                return col
            display_columns = [clean_col(col) for col in header_columns]
            df = pd.DataFrame(result_rows, columns=display_columns)
            self.current_view.update_results_table(df)
    
    def _on_console_output(self, line):
        """Callback for when there's output to the console"""
        if self.current_view:
            self.current_view.write_to_console(line)
    
    def _on_search_completed(self):
        """Callback for when a search process completes"""
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
            'stake': 'stake'
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
            'stake': 'stake'
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
        
        return True