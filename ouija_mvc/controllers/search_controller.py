"""
Search Controller - Handles search operations and process management
"""

import os
import time
import json
import threading
from tkinter import messagebox
from ..utils.result import Result


class SearchController:
    """Controller for search operations"""
    
    def __init__(self, search_model, config_controller, database_controller):
        self.search_model = search_model
        self.config_controller = config_controller
        self.database_controller = database_controller
        self.current_view = None
        
        # Timer management
        self.update_timer_id = None
        self.auto_refresh_timer_id = None
        self.update_debounce_ms = 500
        self.auto_refresh_interval_ms = 2000
        
        # Search state
        self.pending_results = None
        self.pending_headers = None
        
        # Set up callbacks for the search model
        self.search_model.set_callbacks(
            results_callback=self._on_search_results,
            console_callback=self._on_console_output,
            process_finished_callback=self._on_search_completed,
        )
        
    def register_view(self, view):
        """Register the main view for callbacks"""
        self.current_view = view
        
    def run_search(self):
        """Start the search process
        
        Returns:
            Result: Success/failure with error details
        """
        if self.search_model.has_active_searches():
            return self.stop_search()

        config_path = self.config_controller.config_model.get_command_config_path()
        if not config_path:
            return Result.error("Failed to prepare configuration for search")

        # Ensure database connection
        db_result = self.database_controller.ensure_connection(config_path)
        if not db_result:
            return Result.error("Failed to connect to database")

        # Start the search
        success = self.search_model.start_search(
            config_path=config_path,
            starting_seed=self.config_controller.get_setting("starting_seed"),
            thread_groups=self.config_controller.get_setting("thread_groups"),
            number_of_seeds=self.config_controller.get_setting("number_of_seeds"),
            db_model=self.database_controller.database_model,
            cutoff=self.config_controller.get_setting("cutoff"),
            gpu_batch=self.config_controller.get_setting("gpu_batch"),
            template=self.config_controller.get_setting("template"),
            filter_name=self.config_controller.get_config_name(),
        )
        
        if success:
            if self.current_view:
                self.current_view.set_search_running(True)
                self.current_view.set_status("Search started...")
            return Result.success("Search started")
        else:
            if self.current_view:
                self.current_view.set_search_running(False)
            return Result.error("Failed to start search")

    def stop_search(self):
        """Stop all active search processes
        
        Returns:
            Result: Success/failure with error details
        """
        try:
            success = self.search_model.stop_all_searches()
            if self.current_view:
                if success:
                    self.current_view.set_search_running(False)
                    self.current_view.set_status("Search stopped.")
                else:
                    self.current_view.set_status("Failed to stop search.")
            
            return Result.success("Search stopped") if success else Result.error("Failed to stop search")
        except Exception as e:
            if self.current_view:
                self.current_view.set_status(f"Error stopping search: {str(e)}")
            return Result.error(f"Error stopping search: {str(e)}")

    def _on_search_results(self, header_columns, result_rows):
        """Callback for when search results are available"""
        if self.current_view:
            # Cancel any pending update
            if self.update_timer_id:
                self.current_view.root.after_cancel(self.update_timer_id)

            # Schedule a new update
            self.update_timer_id = self.current_view.root.after(
                self.update_debounce_ms, self._process_pending_results)

    def _process_pending_results(self):
        """Process pending results after debounce period"""
        self.update_timer_id = None
        
        # Refresh results directly from the database
        self.database_controller.refresh_results()
        
        # Clear any potentially lingering pending results
        self.pending_results = None
        self.pending_headers = None

    def _on_console_output(self, line):
        """Callback for when there's output to the console"""
        if not self.current_view:
            return
            
        # Check if this is a status message
        if line.startswith("STATUS:"):
            self._handle_status_message(line)
        else:
            # Regular console output
            self.current_view.write_to_console(line)

    def _handle_status_message(self, line):
        """Handle status message formatting"""
        status_message = line[7:].strip()  # Remove "STATUS:" prefix

        # Format time display
        import re

        def format_time(match):
            seconds = float(match.group(1))
            days, remainder = divmod(seconds, 86400)
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

        # Replace time values in status message
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
            parts = status_message.split("⏱️")
            if len(parts) == 2:
                self.current_view.set_status(parts[0].strip())
                self.current_view.set_metrics(f"⏱️{parts[1].strip()}")
            else:
                self.current_view.set_status(status_message)
        else:
            self.current_view.set_status(status_message)

    def _on_search_completed(self):
        """Callback for when a search process completes"""
        try:
            self.database_controller.refresh_results()
            if self.current_view:
                self.current_view.write_to_console("--- Search Complete ---\n")
                self.current_view.set_search_running(False)
        except Exception as e:
            if self.current_view:
                self.current_view.write_to_console(f"⚠️ Error in search completion: {e}\n")
            print(f"Error in _on_search_completed: {e}")

    def cleanup(self):
        """Clean up search resources"""
        # Stop any active searches
        self.search_model.stop_all_searches()

        # Cancel any pending updates
        if self.update_timer_id and self.current_view:
            self.current_view.root.after_cancel(self.update_timer_id)

        # Stop auto-refresh if running
        self._stop_auto_refresh()

    def _stop_auto_refresh(self):
        """Stop the auto-refresh timer"""
        if self.auto_refresh_timer_id and self.current_view:
            self.current_view.root.after_cancel(self.auto_refresh_timer_id)
            self.auto_refresh_timer_id = None
