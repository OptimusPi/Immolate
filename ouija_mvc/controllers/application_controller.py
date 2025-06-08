"""
Application Controller - Handles interactions between models and views
"""

import os
import time
import json
import subprocess
import threading
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
        self.auto_refresh_timer_id = None  # Timer for auto-refreshing during fun searches
        self.pending_results = None
        self.pending_headers = None
        self.update_debounce_ms = 500  # Update UI at most 1/2 every second
        self.auto_refresh_interval_ms = 2000  # 2 seconds

        # Set up callbacks for the search model
        self.search_model.set_callbacks(
            results_callback=self._on_search_results,
            console_callback=self._on_console_output,
            process_finished_callback=self._on_search_completed,
        )
        # Initialize state for Funny List search mode
        self.funny_list_active = False
        self.funny_list_words = []
        self.current_funny_list_index = 0
        self.current_config_path_for_search = None
        self.prank_search_active = False
        self.prank_search_processes = []
        self.prank_search_stop_requested = False

        # Fun search state variables
        self.fun_search_category = None
        self.fun_search_words = []
        self.fun_search_padding_levels = []
        self.fun_search_current_word_index = 0
        self.fun_search_current_padding_index = 0

        self.build_running = False  # Track if a build is running

        # Set up callback for database table reset to refresh UI
        self.database_model.on_results_table_reset = self.refresh_results

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
                messagebox.showerror(
                    "Error",
                    "Please enter a configuration name before saving.")
            return False

        success, result = self.config_model.save_config(file_path)
        if success and self.current_view:
            self.current_view.set_status(f"Configuration saved: {result}")
        elif not success and self.current_view:
            messagebox.showerror("Error",
                                 f"Failed to save configuration: {result}")

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

    def get_config_description(self):
        """Get current configuration description"""
        return self.config_model.config_description

    def set_config_description(self, description):
        """Set configuration description"""
        self.config_model.config_description = description
        self.config_model.config_modified = True

    def get_config_author(self):
        """Get current configuration author"""
        return self.config_model.config_author

    def set_config_author(self, author):
        """Set configuration author"""
        self.config_model.config_author = author
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

    def get_criteria(self):
        """Retrieve the current criteria from the model."""
        return self.config_model.get_criteria()

    # Search management
    def run_search(self):
        """Start the search process"""
        if self.search_model.has_active_searches() or self.prank_search_active:
            # If a search is running, the button acts as a stop button
            self.stop_search()
            return

        config_path = self.config_model.get_command_config_path()
        if not config_path:
            if self.current_view:
                messagebox.showerror(
                    "Error", "Failed to prepare configuration for search.")
            return False

        db_path = self.database_model.get_db_path_from_config(config_path)
        if not os.path.exists(db_path):
            # Ensure DB connection is established if DB file doesn't exist
            self.database_model.connect(config_path)
            self.database_model.close(
            )  # Close immediately if only for creation

        # Always ensure the database is connected before a search
        self.database_model.connect(config_path)

        # Normal search (Default/Key Word)
        success = self.search_model.start_search(
            config_path=config_path,
            starting_seed=self.get_setting("starting_seed"),
            thread_groups=self.get_setting("thread_groups"),
            number_of_seeds=self.get_setting("number_of_seeds"),
            db_model=self.database_model,
            cutoff=self.get_setting("cutoff"),
            gpu_batch=self.get_setting("gpu_batch"),
            template=self.get_setting("template"),
        )
        if success and self.current_view:
            self.current_view.set_search_running(True)
            self.current_view.set_status("Search started...")
        elif not success and self.current_view:
            self.current_view.set_search_running(False)
            messagebox.showerror("Error", "Failed to start search.")
        return success

    def stop_search(self):
        """Stop all active search processes and cancel any fun/prank batch in progress"""
        try:
            # Cancel any fun/prank batch in progress
            self.prank_search_active = False
            self.fun_search_category = None
            self.fun_search_words = []
            self.fun_search_padding_levels = []
            self.fun_search_current_word_index = 0
            self.fun_search_current_padding_index = 0
            self._stop_auto_refresh()

            success = self.search_model.stop_all_searches()
            if self.current_view:
                if success:
                    self.current_view.set_search_running(False)
                    self.current_view.set_status("Search stopped.")
                else:
                    self.current_view.set_status("Failed to stop search.")
            return success
        except Exception as e:
            if self.current_view:
                self.current_view.set_status(
                    f"Error stopping search: {str(e)}")
            return False

    def _on_search_results(
            self, header_columns,
            result_rows):  # header_columns and result_rows are now None
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
                    days, remainder = divmod(seconds,
                                             86400)  # 86400 seconds in a day
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

                status_message = re.sub(
                    r"Elapsed time: (\d+\.\d+) seconds",
                    lambda m: f"Elapsed time: {format_time(m)}",
                    status_message,
                )
                status_message = re.sub(
                    r"Estimated remaining time: (\d+\.\d+) seconds",
                    lambda m: f"Estimated remaining time: {format_time(m)}",
                    status_message,
                )

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
        try:
            if self.prank_search_active:
                # Check if this is a fun search (has fun_search_category) or regular prank search
                if hasattr(self, 'fun_search_category') and self.fun_search_category:
                    # Fun search mode - handle sequential word/padding combinations
                    if (self.fun_search_current_word_index
                            < len(self.fun_search_words)):
                        word = self.fun_search_words[
                            self.fun_search_current_word_index]
                        if self.current_view and word:
                            self.current_view.write_to_console(
                                f"✅ Completed: {word}\n")
                            self.current_view.refresh_results_table()  # Force table refresh after each fun search
                    # Advance to next search
                    self._advance_fun_search_indices()

                    # Check if we're done with all combinations
                    if self.fun_search_current_word_index >= len(
                            self.fun_search_words):
                        # Fun search fully complete
                        self.prank_search_active = False
                        self.fun_search_category = None  # Clear the flag
                        self._stop_auto_refresh()  # Stop auto-refresh when done
                        if self.current_view:
                            self.current_view.write_to_console(
                                "🎉 All fun searches complete! Check your results! 🎉\n"
                            )
                            self.current_view.set_search_running(False)
                        self.refresh_results()
                    else:
                        # More combinations to search - continue
                        self._run_next_fun_search()
                else:
                    # Fun search mode - handle the next word in the current sequence
                    if (self.fun_search_current_word_index
                            < len(self.fun_search_words)):
                        word = self.fun_search_words[
                            self.fun_search_current_word_index]
                        if self.current_view and word:
                            self.current_view.write_to_console(
                                f"✅ Completed: {word}\n")

                    # Continue with next search in sequence
                    self._run_next_fun_search()

                    # Check if we've completed all searches in the category
                    if (self.fun_search_current_word_index >= len(
                            self.fun_search_words)
                            and self.fun_search_current_padding_index >= len(
                                self.fun_search_padding_levels)):
                        # Fun search fully complete - reset search state
                        self.prank_search_active = False
                        if self.current_view:
                            self.current_view.write_to_console(
                                f"🎉 All {self.fun_search_category} searches complete! Check your results! 🎉\n"
                            )
                            self.current_view.set_search_running(False)
                        self.refresh_results()
                        self._stop_auto_refresh()
                    else:
                        # More words to search - continue
                        self._run_next_prank_search()
            else:
                # Normal search completion handling
                self.refresh_results()
                if self.current_view:
                    self.current_view.write_to_console(
                        "--- Search Complete ---\n")
                    self.current_view.set_search_running(False)
        except Exception as e:
            # Log the error but don't crash the UI
            if self.current_view:
                self.current_view.write_to_console(
                    f"⚠️ Error in search completion: {e}\n")
            print(f"Error in _on_search_completed: {e}")
            # Reset prank search state to prevent further issues
            self.prank_search_active = False
            if hasattr(self, 'fun_search_category'):
                self.fun_search_category = None
            if self.current_view:
                self.current_view.set_search_running(False)

    # User preference methods
    def get_setting(self, key, default=None):
        """Get a user setting value"""
        # Map settings to config_model properties
        settings_map = {
            "thread_groups": "thread_groups",
            "starting_seed": "starting_seed",
            "number_of_seeds": "number_of_seeds",
            "deck": "deck",
            "stake": "stake",
            "cutoff": "cutoff",
            "gpu_batch": "gpu_batch",
            "template": "template"
        }

        if key in settings_map:
            return getattr(self.config_model, settings_map[key], default)
        return default

    def set_setting(self, key, value):
        """Set a user setting value"""
        # Map settings to config_model properties
        settings_map = {
            "thread_groups": "thread_groups",
            "starting_seed": "starting_seed",
            "number_of_seeds": "number_of_seeds",
            "deck": "deck",
            "stake": "stake",
            "cutoff": "cutoff",
            "gpu_batch": "gpu_batch",
            "template": "template"
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

        # Stop auto-refresh if running
        self._stop_auto_refresh()

        return True

    def refresh_results(self):
        """Refresh results from the database"""
        df = self.database_model.get_dataframe()
        if df is not None and self.current_view:
            self.current_view.update_results_table(df)
        return df is not None

    def delete_all_results(self):
        """Delete all results from the database

        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Get the current config path to determine which database to clear
            with open("ouija_user.conf", "r") as f:
                user_conf = json.load(f)
            config_path = user_conf.get("last_config_path")

            if config_path and self.database_model.connect(config_path):
                success = self.database_model.delete_all_results()
                if success:
                    # Refresh the view to show empty table
                    self.refresh_results()
                return success
            else:
                print(
                    'ERROR deleting all results: No config path found or database connection failed.'
                )
                return False
        except Exception as e:
            print(f"Error deleting all results: {e}")
            return False

    def export_results(self, file_path, export_format="csv", limit=None):
        """Export results to file
        
        Args:
            file_path: Path where file will be saved
            export_format: Format to export ("csv", "excel", "json")
            limit: Maximum number of rows to export (None for all)
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Ensure database is connected
            config_path = self.config_model.loaded_config_path
            if not config_path or not self.database_model.connect(config_path):
                return False

            # Export based on format
            if export_format.lower() == "csv":
                return self.database_model.export_to_csv(file_path, limit)
            elif export_format.lower() == "excel":
                return self.database_model.export_to_excel(file_path, limit)
            elif export_format.lower() == "json":
                return self.database_model.export_to_json(file_path, limit)
            else:
                return False

        except Exception as e:
            print(f"Error exporting results: {e}")
            return False

    def get_export_info(self):
        """Get information about exportable data
        
        Returns:
            dict: Export statistics and info
        """
        try:
            config_path = self.config_model.loaded_config_path
            if config_path and self.database_model.connect(config_path):
                return self.database_model.get_export_stats()
            return {"total_rows": 0, "columns": []}
        except Exception as e:
            print(f"Error getting export info: {e}")
            return {"total_rows": 0, "columns": []}

    def run_prank_seed_search(self):
        """Run a prank seed search (NSFW category)
        
        This method is called by the dialog's prank button and delegates
        to the main fun seed search with the NSFW category.
        
        Returns:
            bool: True if search started successfully, False otherwise
        """
        return self.run_fun_seed_search("NSFW")

    def run_fun_seed_search(self, category):
        """Run a fun seed search for a specific category
        
        Args:
            category: Category of fun seeds to search for ("LOL", "GROSS", "NSFW", "COOL")
            
        Returns:
            bool: True if search started successfully, False otherwise
        """        
        try:
            fun_words = {
                "LOL": ["LMAO", "ROFL", "HAHA", "JOKE", "MEME", "EPIC", "FAIL", "DERP", "NOOB", "YOLO", "SWAG", "REKT", "TROLL", "PLEB", "KEKS", "LULZ"],
                "GROSS": ["FART", "BURP", "SNOT", "POOP", "SLIME", "YUCK", "EWWW", "SICK", "VOMIT", "GUNK", "CRUD", "MOLD", "GRIME", "BILE", "DROOL", "SCUM"],
                "NSFW": ["SEXY", "BOOB", "BUTT", "DAMN", "HELL", "SUCK", "BEER", "WINE", "SHOT", "BLOW", "DRUG", "WEED", "HIGH", "DOPE", "ACID", "BUZZ"],
                "COOL": ["FIRE", "DOPE", "SICK", "EPIC", "RAGE", "WILD", "BOSS", "HERO", "STAR", "GOLD", "RICH", "FAST", "MEGA", "HUGE", "ROCK", "KING"]
            }

            if category not in fun_words:
                if self.current_view:
                    messagebox.showerror(
                        "Error", f"Unknown fun search category: {category}")
                return False

            if self.search_model.has_active_searches() or self.prank_search_active:
                if self.current_view:
                    messagebox.showwarning(
                        "Warning",
                        "A search is already running. Please stop it first.")
                return False

            # Generate all valid seeds for each word with all possible left/right/distributed '1' paddings, for lengths from len(word)+1 to 8
            fun_seeds = []  # List of (seed, right_pad_count)
            for word in fun_words[category]:
                max_pad = 8 - len(word)
                if max_pad < 1:
                    continue  # skip words too long
                # For each possible total padding (from 1 to max_pad), always require at least 1 right pad
                for total_pad in range(1, max_pad + 1):
                    for left in range(0, total_pad):
                        right = total_pad - left
                        if right < 1:
                            continue  # must have at least one right pad
                        seed = ("1" * left) + word + ("1" * right)
                        if len(seed) <= 8:
                            fun_seeds.append((seed, right))
            # Remove duplicates (some seeds may be generated twice)
            fun_seeds = list(dict.fromkeys(fun_seeds))

            self.fun_search_category = category
            self.fun_search_words = fun_seeds  # Now a list of (seed, right_pad_count)
            self.fun_search_current_word_index = 0
            self.prank_search_active = True

            if self.current_view:
                self.current_view.write_to_console(
                    f"🎭 Starting {category} fun seed search!\n")
                self.current_view.set_search_running(True)
            return self._run_next_fun_search()
        except Exception as e:
            if self.current_view:
                messagebox.showerror("Error",
                                     f"Failed to start fun search: {e}")
            return False

    def _run_next_fun_search(self):
        try:
            if self.fun_search_current_word_index >= len(self.fun_search_words):
                return False
            search_term, right_pad_count = self.fun_search_words[self.fun_search_current_word_index]
            # Set n_value based on right_pad_count (number of rightmost '1's)
            n_value = 35 ** right_pad_count if right_pad_count > 0 else 35
            if self.current_view:
                self.current_view.write_to_console(
                    f"    🔍 Searching: {search_term} (n={n_value})\n")
            config_path = self.config_model.get_command_config_path()
            if not config_path:
                return False
            self.database_model.connect(config_path)
            success = self.search_model.start_search(
                config_path=config_path,
                starting_seed=search_term,
                thread_groups=self.get_setting("thread_groups"),
                number_of_seeds=n_value,
                db_model=self.database_model,
                cutoff=self.get_setting("cutoff"),
                gpu_batch=self.get_setting("gpu_batch"),
                template=self.get_setting("template"),
            )
            return success
        except Exception as e:
            if self.current_view:
                self.current_view.write_to_console(
                    f"❌ Error in fun search: {e}\n")
            return False

    def _advance_fun_search_indices(self):
        self.fun_search_current_word_index += 1

    def _stop_auto_refresh(self):
        """Stop the auto-refresh timer"""
        if self.auto_refresh_timer_id and self.current_view:
            self.current_view.root.after_cancel(self.auto_refresh_timer_id)
            self.auto_refresh_timer_id = None

    def _auto_refresh_callback(self):
        """Callback for auto-refreshing during fun/prank seed searches"""
        if self.current_view:
            self.current_view.refresh_results_table()
        # Schedule the next auto-refresh if still active
        if getattr(self, 'prank_search_active', False) and self.current_view:
            self.auto_refresh_timer_id = self.current_view.root.after(
                self.auto_refresh_interval_ms, self._auto_refresh_callback)

    def _run_build_script(self, on_complete=None):
        """Run build.ps1 -PrecompileKernels and stream output to the console. Calls on_complete when done."""
        def run_and_stream():
            try:
                # Use subprocess.Popen to run the build script and stream output
                process = subprocess.Popen([
                    'powershell', '-ExecutionPolicy', 'Bypass', '-File', 'build.ps1', '-PrecompileKernels'
                ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=os.getcwd())
                if self.current_view:
                    self.current_view.write_to_console("\n⚙️ Running kernel build...\n")
                for line in process.stdout:
                    if self.current_view:
                        self.current_view.write_to_console(line)
                process.wait()
                if process.returncode == 0:
                    if self.current_view:
                        self.current_view.write_to_console("\n✅ Kernel build complete!\n")
                    # Mark installation success in ouija_user.conf
                    try:
                        conf_path = os.path.join(os.getcwd(), 'ouija_user.conf')
                        if os.path.exists(conf_path):
                            with open(conf_path, 'r') as f:
                                conf = json.load(f)
                        else:
                            conf = {}
                        conf['installation_success'] = True
                        with open(conf_path, 'w') as f:
                            json.dump(conf, f, indent=2)
                    except Exception as e:
                        if self.current_view:
                            self.current_view.write_to_console(f"[Warning] Could not update ouija_user.conf: {e}\n")
                else:
                    if self.current_view:
                        self.current_view.write_to_console("\n❌ Kernel build failed!\n")
                if on_complete:
                    on_complete()
            except Exception as e:
                if self.current_view:
                    self.current_view.write_to_console(f"[Error] Kernel build crashed: {e}\n")
                if on_complete:
                    on_complete()
        # Run in a thread so the UI doesn't freeze
        threading.Thread(target=run_and_stream, daemon=True).start()

    def is_kernel_build_needed(self):
        """Check if kernel binaries are missing or installation is incomplete."""
        # Check ouija_user.conf for installation_success
        conf_path = os.path.join(os.getcwd(), 'ouija_user.conf')
        try:
            if os.path.exists(conf_path):
                with open(conf_path, 'r') as f:
                    conf = json.load(f)
                if conf.get('installation_success'):
                    return False
        except Exception:
            pass
        # Check for Ouija.exe and at least one .bin kernel file
        exe_path = os.path.join(os.getcwd(), 'Ouija.exe')
        kernels_dir = os.path.join(os.getcwd(), 'filters')
        has_exe = os.path.exists(exe_path)
        has_bin = False
        if os.path.isdir(kernels_dir):
            for fname in os.listdir(kernels_dir):
                if fname.endswith('.bin'):
                    has_bin = True
                    break
        return not (has_exe and has_bin)

    def run_kernel_build(self, on_complete=None):
        """Public method to trigger kernel build and track build state."""
        if self.build_running:
            if self.current_view:
                self.current_view.write_to_console("[Info] Kernel build already running.\n")
            return
        self.build_running = True
        def build_done():
            self.build_running = False
            if on_complete:
                on_complete()
            # Optionally notify the UI
            if self.current_view:
                self.current_view.set_status("Kernel build finished.")
        self._run_build_script(on_complete=build_done)

    def get_current_config_path(self):
        """Return the currently loaded config path, or None if not set."""
        return getattr(self.config_model, "loaded_config_path", None)
