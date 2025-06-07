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

    def _on_search_results(self, header_columns, result_rows):
        """Callback for when search results are available (signals to refresh from DB)"""
        if self.current_view:
            # Cancel any pending update
            if self.update_timer_id:
                self.current_view.root.after_cancel(self.update_timer_id)
            # Schedule a new update (which will now just call refresh_results)
            self.update_timer_id = self.current_view.root.after(
                self.update_debounce_ms, self._process_pending_results)

    def _process_pending_results(self):
        """Process and refresh results in the UI."""
        self.refresh_results()

    def _on_console_output(self, line):
        """Callback for when there's output to the console"""
        if self.current_view:
            if isinstance(line, str) and line.startswith("STATUS:"):
                status_text = line[len("STATUS:"):].strip()
                import re
                # If the line contains a stopwatch emoji and a speed, extract and send to set_metrics
                metrics_match = re.search(r"(⏱️ ?[\d\.]+[KMG]?/s)", status_text)
                if metrics_match:
                    self.current_view.set_metrics(metrics_match.group(1))
                    # Remove the metrics part from the status text (if there's more left, show it as status)
                    status_text_clean = status_text.replace(metrics_match.group(1), '').strip()
                    if status_text_clean:
                        self.current_view.set_status(status_text_clean)
                else:
                    self.current_view.set_status(status_text)
            else:
                self.current_view.write_to_console(line)

    def _on_search_completed(self):
        """Callback for when a search process completes"""
        if self.current_view:
            self.current_view.write_to_console("--- Search Complete ---\n")
            # Only set button to inactive if not in a fun search batch
            if not self.fun_search_active:
                self.current_view.set_search_running(False)

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
        # Remove prank search variables, use fun search only
        self.fun_search_active = False
        self.fun_search_processes = []
        self.fun_search_stop_requested = False

        # Fun search state variables
        self.fun_search_category = None
        self.fun_search_words = []
        self.fun_search_padding_levels = []
        self.fun_search_current_word_index = 0
        self.fun_search_current_padding_index = 0

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
        if self.search_model.has_active_searches() or self.fun_search_active:
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
        """Stop the currently active search process"""
        if self.fun_search_active:
            self.stop_fun_search()
            return
        if self.search_model.has_active_searches():
            self.search_model.stop_all_searches()
            if self.current_view:
                self.current_view.set_status("Search stopped by user.")
                self.current_view.set_search_running(False)
        self.funny_list_active = False

    def run_fun_seed_search(self, category="NSFW"):
        """Run the fun seed search feature for a specific category with all padding levels
        
        Args:
            category: Category of fun seeds to search for ("LOL", "GROSS", "NSFW", "COOL")
        
        Returns:
            bool: True if search started successfully, False otherwise
        """
        if self.fun_search_active:
            self.stop_fun_search()
            # Wait for the stop to complete before starting a new search
            def start_after_stop():
                if self.search_model.has_active_searches():
                    # Poll until all searches are stopped
                    if self.current_view:
                        self.current_view.root.after(100, start_after_stop)
                    return
                # Now start the new fun search
                self._start_fun_seed_search(category)
            if self.current_view:
                self.current_view.root.after(100, start_after_stop)
            return True
        else:
            return self._start_fun_seed_search(category)

    def _start_fun_seed_search(self, category):
        fun_word_lists = {
            "LOL": [
                "LMAO", "ROFL", "HAHA", "JOKE", "MEME", "EPIC", "FAIL", "DERP",
                "NOOB", "YOLO", "SWAG", "REKT", "TROLL", "PLEB", "KEKS", "LULZ"
            ],
            "GROSS": [
                "FART", "BURP", "SNOT", "POOP", "SLIME", "YUCK", "EWWW", "SICK",
                "VOMIT", "GUNK", "CRUD", "MOLD", "GRIME", "BILE", "DROOL", "SCUM"
            ],
            "NSFW": [
                "SEXY", "BOOB", "BUTT", "DAMN", "HELL", "SUCK", "BEER", "WINE",
                "SHOT", "BLOW", "DRUG", "WEED", "HIGH", "DOPE", "ACID", "BUZZ"
            ],
            "COOL": [
                "FIRE", "DOPE", "SICK", "EPIC", "RAGE", "WILD", "BOSS", "HERO",
                "STAR", "GOLD", "RICH", "FAST", "MEGA", "HUGE", "ROCK", "KING"
            ]
        }
        if category not in fun_word_lists:
            if self.current_view:
                messagebox.showerror("Error", f"Unknown category: {category}")
            return False
        if self.search_model.has_active_searches():
            if self.current_view:
                messagebox.showwarning(
                    "Search Active",
                    "Please stop the current search before starting a fun seed search.",
                )
            return False
        config_path = self.config_model.get_command_config_path()
        if not config_path:
            if self.current_view:
                messagebox.showerror(
                    "Error", "Failed to prepare configuration for fun seed search."
                )
            return False
        padding_levels = [1, 2, 3, 4]
        
        word_count = len(fun_word_lists[category])
        total_searches = word_count * len(padding_levels)
        self.current_view.write_to_console(f"🎉 Starting {category} seed search!\n")
        self.current_view.write_to_console("=" * 50 + "\n")
        self.current_view.write_to_console(f"Category: {category}\n")
        self.current_view.write_to_console(f"Words: {word_count}\n")
        self.current_view.write_to_console(f"Padding levels: {len(padding_levels)} (1, 11, 111, 1111)\n")
        self.current_view.write_to_console(f"Total searches: {total_searches}\n")
        self.current_view.write_to_console("=" * 50 + "\n")
        self.current_view.set_search_running(True)  # Always set STOP SEARCH at start
        self.fun_search_active = True
        self.fun_search_category = category
        self.fun_search_words = fun_word_lists[category]
        self.fun_search_padding_levels = padding_levels
        self.fun_search_current_word_index = 0
        self.fun_search_current_padding_index = 0
        self.fun_search_position_index = 0  # Always reset position index at start
        self._run_next_fun_search()
        return True

    def stop_fun_search(self):
        """Stop the active fun search"""
        if not self.fun_search_active:
            return False
        self.fun_search_active = False
        self.fun_search_stop_requested = True
        if self.search_model.has_active_searches():
            self.search_model.stop_all_searches()
            if self.current_view:
                self.current_view.write_to_console("🛑 Fun seed search stopped by user.\n")
                self.current_view.set_status("Search stopped by user.")
                self.current_view.set_search_running(False)  # Set Let Jimbo Cook at end only
        else:
            if self.current_view:
                self.current_view.set_search_running(False)
        return True

    def _run_next_fun_search(self):
        """Run the next word/padding combo in the fun search sequence, strictly sequentially (never in parallel), and try all left-padded positions."""
        if not self.fun_search_active or self.fun_search_stop_requested:
            self.fun_search_active = False
            self.fun_search_stop_requested = False
            if self.current_view:
                self.current_view.set_search_running(False)
                self.current_view.set_status("Fun seed search stopped or complete.")
            return
        words = self.fun_search_words
        paddings = self.fun_search_padding_levels
        widx = self.fun_search_current_word_index
        pidx = self.fun_search_current_padding_index
        # New: try all left-padded positions for each word/padding
        if not hasattr(self, 'fun_search_position_index'):
            self.fun_search_position_index = 0
        positions = []
        padding = paddings[pidx]
        word = words[widx]
        word_len = len(word)
        total_len = word_len + padding
        for i in range(0, total_len - word_len):
            if total_len - (i + word_len) > 0:
                positions.append(i)
        if 0 not in positions:
            positions.insert(0, 0)
        positions = sorted(set(positions))
        if self.fun_search_position_index >= len(positions):
            self.fun_search_position_index = 0
            self.fun_search_current_padding_index += 1
            if self.fun_search_current_padding_index >= len(paddings):
                self.fun_search_current_padding_index = 0
                self.fun_search_current_word_index += 1
            self._run_next_fun_search()
            return
        pos = positions[self.fun_search_position_index]
        left_pad = "1" * pos
        right_pad = "1" * (total_len - pos - word_len)
        start_seed = f"{left_pad}{word}{right_pad}"
        num_seeds = 35 ** (total_len - len(word))
        if right_pad == "":
            self.fun_search_position_index += 1
            self._run_next_fun_search()
            return
        if self.current_view:
            # Do NOT set_search_running(True) here; only set at start of batch
            progress = ((widx * len(paddings) * len(positions) + pidx * len(positions) + self.fun_search_position_index + 1) /
                        (len(words) * len(paddings) * len(positions))) * 100
            self.current_view.write_to_console(
                f"\n🎯 [{widx * len(paddings) * len(positions) + pidx * len(positions) + self.fun_search_position_index + 1}/"
                f"{len(words) * len(paddings) * len(positions)}] ({progress:.1f}%) Searching '{start_seed}' (word='{word}', padding={padding}, pos={pos})...\n"
            )
            self.current_view.write_to_console(
                f"    Starting seed: {start_seed} (will search {num_seeds:,} seeds)\n"
            )
        def after_search():
            self.fun_search_position_index += 1
            self._run_next_fun_search()
        def poll():
            while self.search_model.has_active_searches():
                time.sleep(0.2)
            if self.fun_search_active and not self.fun_search_stop_requested:
                # Do NOT set_search_running(True) here; only set at start of batch
                if self.current_view:
                    self.current_view.root.after(100, after_search)
        success = self.search_model.start_search(
            config_path=self.config_model.get_command_config_path(),
            starting_seed=start_seed,
            thread_groups=self.get_setting("thread_groups"),
            number_of_seeds=num_seeds,
            db_model=self.database_model,
            cutoff=self.get_setting("cutoff"),
            gpu_batch=self.get_setting("gpu_batch"),
            template=self.get_setting("template"),
        )
        if not success and self.current_view:
            self.current_view.write_to_console(f"    ❌ Failed to start search for {start_seed}\n")
            self.fun_search_position_index += 1
            self._run_next_fun_search()
            return
        threading.Thread(target=poll, daemon=True).start()

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

    def get_setting(self, key, default=None):
        """Get a setting from the config model, with optional default."""
        return self.config_model.get_setting(key, default)

    def set_setting(self, key, value):
        """Set a setting in the config model."""
        return self.config_model.set_setting(key, value)

    def cleanup(self):
        """Perform any cleanup needed before closing the app."""
        self.config_model.save_user_conf()
        self.stop_search()