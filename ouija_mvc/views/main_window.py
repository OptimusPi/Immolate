"""
Main Window View for Ouija Seed Finder Application
"""
import os
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, font
from tksheet import Sheet
import pandas as pd
import time
from pandastable import Table
import sys

# Import from our own modules
from .dialogs import ItemSelectorDialog
from ..utils.ui_utils import (
    add_tooltip, StatusBar, ScrollableFrame, 
    BLUE, RED, GREEN, BACKGROUND, DARK_BACKGROUND, LIGHT_TEXT
)
from ..utils.game_data import AVAILABLE_ITEMS, get_display_name
from ouija_mvc.models.database_model import DatabaseModel




class MainWindow:
    """Main window view for Ouija Seed Finder application"""
    
    def __init__(self, root, controller):
        """Initialize the main window
        
        Args:
            root: The root Tk window
            controller: The application controller
        """
        self.root = root
        self.controller = controller
        self.start_time = None  # Ensure this always exists
        self.search_running = False
        
        # Register this view with the controller
        controller.register_view(self)
        
        # Apply custom font
        self.setup_font()
        
        # Create main layout frames
        self.create_layout()
        
        # Create widgets in each section
        self.create_config_section()
        self.create_criteria_section() 
        self.create_run_settings_section()
        self.create_results_section()
        
        # Create status bar
        self.status_bar = StatusBar(self.root)
        self.status_bar.pack(side=tk.BOTTOM, fill=tk.X)
        
        # Set up window close handler
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        # Initialize the UI with current settings
        self.update_config_display()
        self.update_criteria_display()
        self.controller.refresh_results()
        
        # Add to __init__
        self._debounce_table_update_id = None
        self._pending_table_df = None
        self._debounce_interval_ms = 100  # 1 second debounce
        self._status_update_id = None
        self._last_results_count = 0
        self._status_update_interval_ms = 1000
        self._search_start_time = None
        self._search_results_count = 0
        self.update_status_bar_periodically()
    
    def setup_font(self):
        """Set up custom font for the application"""
        # Use system monospace font as fallback if m6x11 not available
        self.custom_font = font.nametofont("TkDefaultFont")
        self.custom_font.configure(family="m6x11", size=16)
        self.root.option_add("*Font", self.custom_font)
    
    def create_layout(self):
        """Create the main layout frames"""
        self.settings_frame = tk.Frame(self.root, bg=BACKGROUND)
        self.settings_frame.pack(fill=tk.BOTH, expand=True, padx=2, pady=2)
        
        self.bottom_frame = tk.Frame(self.root, bg=BACKGROUND)
        self.bottom_frame.pack(fill=tk.BOTH, expand=True, padx=2, pady=2)
    
    def create_config_section(self):
        """Create the custom configuration section"""
        self.left_frame = tk.Frame(self.settings_frame, bg=BACKGROUND, width=200)
        self.left_frame.pack_propagate(False)
        self.left_frame.pack(fill=tk.Y, side=tk.LEFT, padx=2, pady=2)
        
        self.config_frame = tk.LabelFrame(self.left_frame, text="Save/Load", 
                                        padx=4, pady=4, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 13))
        self.config_frame.pack(fill=tk.X, expand=False, side=tk.TOP, padx=2, pady=2)
        
        self.config_name_var = tk.StringVar()
        self.config_name_entry = tk.Entry(self.config_frame, textvariable=self.config_name_var, font=("m6x11", 12))
        self.config_name_entry.pack(fill=tk.X, pady=2)
        self.config_name_var.trace("w", self.on_config_name_changed)
        
        button_frame = tk.Frame(self.config_frame, bg=BACKGROUND)
        button_frame.pack(fill=tk.X, pady=2)
        
        self.save_button = tk.Button(button_frame, text="Save", 
                                    command=self.on_save_direct, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 11))
        self.save_button.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0,1))
        
        self.save_as_button = tk.Button(button_frame, text="Save As...", 
                                    command=self.on_save_as, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 11))
        self.save_as_button.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(1,1))
        
        self.load_button = tk.Button(button_frame, text="Load", 
                                    command=self.on_load_config, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 11))
        self.load_button.pack(side=tk.RIGHT, expand=True, fill=tk.X, padx=(1,0))
        
        self.deck_frame = tk.LabelFrame(self.left_frame, text="Deck Parameters", 
                                       padx=4, pady=4, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 13))
        self.deck_frame.pack(fill=tk.X, expand=False, side=tk.TOP, padx=2, pady=2)
        
        self.gpu_options_frame = tk.LabelFrame(self.left_frame, text="GPU Options", 
                                               padx=4, pady=4, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 13))
        self.gpu_options_frame.pack(fill=tk.X, expand=False, side=tk.TOP, padx=2, pady=2)
        
        thread_label = tk.Label(self.gpu_options_frame, text="GPU Thread Groups:", 
                              bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12))
        thread_label.pack(anchor="w", pady=2)
        add_tooltip(thread_label, 
                   "Select the number of GPU thread groups to use. Use 'Single' for analyzing one seed. "
                   "Optimal value differs per system. Experimenting/Benchmarking Recommended!")
        
        self.thread_groups_var = tk.StringVar()
        self.thread_groups_dropdown = ttk.Combobox(self.gpu_options_frame, 
                                                 textvariable=self.thread_groups_var, state="readonly", font=("m6x11", 11))
        self.thread_groups_dropdown['values'] = ["Single", "32"]
        self.thread_groups_dropdown.pack(fill=tk.X, pady=(2, 4))
        self.thread_groups_dropdown.bind("<<ComboboxSelected>>", self.on_thread_groups_changed)
        
        self.deck_var = tk.StringVar()
        self.deck_dropdown = ttk.Combobox(self.deck_frame, textvariable=self.deck_var, state="readonly", font=("m6x11", 11))
        self.deck_dropdown['values'] = AVAILABLE_ITEMS["Decks"]
        self.deck_dropdown.pack(fill=tk.X, pady=2)
        self.deck_dropdown.bind("<<ComboboxSelected>>", self.on_deck_changed)
        
        self.stake_var = tk.StringVar()
        self.stake_dropdown = ttk.Combobox(self.deck_frame, textvariable=self.stake_var, state="readonly", font=("m6x11", 11))
        self.stake_dropdown['values'] = AVAILABLE_ITEMS["Stakes"]
        self.stake_dropdown.pack(fill=tk.X, pady=2)
        self.stake_dropdown.bind("<<ComboboxSelected>>", self.on_stake_changed)
        
        self.seed_settings_frame = tk.LabelFrame(self.left_frame, text="Seed Settings", 
                                                padx=4, pady=4, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 13))
        self.seed_settings_frame.pack(fill=tk.X, expand=False, side=tk.TOP, padx=2, pady=2)
        
        starting_seed_label = tk.Label(self.seed_settings_frame, text="Starting Seed", 
                                     bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12))
        starting_seed_label.pack(anchor="w", pady=2)
        self.starting_seed_var = tk.StringVar()
        vcmd = (self.root.register(self.validate_seed), '%P')
        seed_frame = tk.Frame(self.seed_settings_frame, bg=BACKGROUND)
        seed_frame.pack(fill=tk.X, pady=2)
        self.starting_seed_entry = tk.Text(seed_frame, height=2, width=20, font=("m6x11", 12))
        self.starting_seed_entry.pack(side=tk.LEFT, fill=tk.X, expand=True)
        random_seed_button = tk.Button(seed_frame, text="🎲", bg=GREEN, fg=LIGHT_TEXT, command=self.on_random_seed, font=("m6x11", 12))
        random_seed_button.pack(side=tk.RIGHT, padx=2)
        self.auto_advance_var = tk.BooleanVar()
        auto_advance_check = tk.Checkbutton(seed_frame, text="Auto Advance", variable=self.auto_advance_var, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 11))
        auto_advance_check.pack(side=tk.RIGHT, padx=2)
    
    def create_criteria_section(self):
        """Create the criteria selection section"""
        self.criteria_frame = tk.LabelFrame(self.settings_frame, text="Search Criteria", 
                                          padx=6, pady=6, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 13))
        self.criteria_frame.pack(fill=tk.BOTH, expand=True, side=tk.LEFT, padx=4, pady=4, ipady=0, ipadx=0)
        self.add_criteria_frame = tk.Frame(self.criteria_frame, bg=BACKGROUND)
        self.add_criteria_frame.pack(fill=tk.X, pady=2)
        tk.Button(self.add_criteria_frame, text="+ Joker", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 11),
                command=lambda: self.on_add_need("Jokers")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+ Tarot", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 11),
                command=lambda: self.on_add_need("Tarots")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+ Spectral", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 11),
                command=lambda: self.on_add_need("Spectrals")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+ Tag", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 11),
                command=lambda: self.on_add_need("Tags")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+ Voucher", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 11),
                command=lambda: self.on_add_need("Vouchers")).pack(side=tk.LEFT, padx=1)
        self.criteria_list = tk.Listbox(self.criteria_frame, height=4, bg=DARK_BACKGROUND, fg=LIGHT_TEXT,
                                      selectmode=tk.SINGLE, font=("m6x11", 11))
        self.criteria_list.pack(fill=tk.BOTH, expand=False, padx=2, pady=2)
        self.criteria_buttons_frame = tk.Frame(self.criteria_frame, bg=BACKGROUND)
        self.criteria_buttons_frame.pack(fill=tk.X, pady=2)
        tk.Button(self.criteria_buttons_frame, text="Randomize! 🎲", 
                command=self.on_randomize, bg=GREEN, fg=LIGHT_TEXT, font=("m6x11", 11)).pack(side=tk.LEFT, padx=1)
        tk.Button(self.criteria_buttons_frame, text="Clear All", 
                command=self.on_clear_all, bg=RED, fg=LIGHT_TEXT, font=("m6x11", 11)).pack(side=tk.RIGHT, padx=1)
        tk.Button(self.criteria_buttons_frame, text="Remove Selected", 
                command=self.on_remove_selected, bg=RED, fg=LIGHT_TEXT, font=("m6x11", 11)).pack(side=tk.RIGHT, padx=1)
    
    def create_run_settings_section(self):
        """Create the run settings section"""
        self.run_settings_frame = tk.LabelFrame(self.settings_frame, text="Run Settings", 
                                              padx=6, pady=6, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 13))
        self.run_settings_frame.pack(fill=tk.BOTH, expand=True, side=tk.LEFT, padx=4, pady=4)
        
        number_of_seeds_label = tk.Label(self.run_settings_frame, text="Search Size", 
                                       bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12))
        number_of_seeds_label.pack(anchor="w", pady=2)
        
        self.number_of_seeds_var = tk.StringVar()
        self.number_of_seeds_dropdown = ttk.Combobox(self.run_settings_frame, 
                                                   textvariable=self.number_of_seeds_var, state="readonly", font=("m6x11", 11))
        self.number_of_seeds_dropdown['values'] = ["Single (1)", "Default (All Seeds)", "1K", "100K", "1M", "100M", "1B"]
        self.number_of_seeds_dropdown.pack(fill=tk.X, pady=2)
        self.number_of_seeds_dropdown.bind("<<ComboboxSelected>>", self.on_number_of_seeds_changed)
        
        self.run_button = tk.Button(self.run_settings_frame, text="Let Jimbo Cook!", 
                                  command=self.on_run_search, 
                                  bg=BLUE, fg=LIGHT_TEXT, 
                                  font=("m6x11", 15, "bold"), height=1, width=18)
        self.run_button.pack(pady=(8, 2))
    
    def create_results_section(self):
        """Create the console output and results table section"""
        self.output_text = tk.Text(self.run_settings_frame, wrap=tk.WORD, height=6, 
                                 bg=DARK_BACKGROUND, fg=LIGHT_TEXT, 
                                 font=("m6x11", 12), insertbackground='white')
        self.output_text.pack(fill=tk.BOTH, side=tk.RIGHT, expand=False, padx=(5, 0), pady=0)
        self.results_frame = tk.Frame(self.bottom_frame, bg=BACKGROUND)
        self.results_frame.pack(fill=tk.BOTH, expand=True)
        # Embedded pandastable
        self.pt = Table(self.results_frame, dataframe=pd.DataFrame(), showtoolbar=False, showstatusbar=False)
        self.pt.show()
        self.latest_df = None
        self._setup_initial_table()

    def _setup_initial_table(self):
        import json
        try:
            with open('ouija_user.conf', 'r') as f:
                user_conf = json.load(f)
            config_path = user_conf.get('last_config_path')
        except Exception:
            config_path = None
        def load_df():
            from ouija_mvc.models.database_model import DatabaseModel
            db_model = DatabaseModel()
            if config_path and db_model.connect(config_path) and db_model.table_exists():
                self.latest_df = db_model.get_dataframe()
                self.pt.model.df = self.latest_df
                self.pt.redraw()
                self.pt.autoResizeColumns()
        self.root.after(100, load_df)

    def update_results_table(self, dataframe):
        self.latest_df = dataframe
        self.pt.model.df = dataframe
        self.pt.redraw()
        self.pt.autoResizeColumns()
        self._search_results_count = len(dataframe) if dataframe is not None else 0
    
    def set_search_running(self, is_running):
        """Update the UI state when search is running or stops
        
        Args:
            is_running: Boolean indicating if search is running
        """
        self.search_running = is_running
        if is_running:
            self.run_button.config(text="STOP SEARCH", bg=RED)
            self._search_start_time = time.time()
            self._search_results_count = 0
        else:
            self.run_button.config(text="Let Jimbo Cook!", bg=BLUE)
            if self.start_time is not None:
                elapsed = time.time() - self.start_time
                self.write_to_console(f"Search finished. Elapsed time: {elapsed:.2f} seconds\n")
            self._search_start_time = None
    
    def write_to_console(self, text):
        """Write text to the console output
        
        Args:
            text: Text to write to console
        """
        self.output_text.insert(tk.END, text)
        self.output_text.see(tk.END)
    
    def set_status(self, text):
        """Set status bar text
        
        Args:
            text: Status text to display
        """
        self.status_bar.set_status(text)
    
    def get_available_items(self):
        """Get the available items by category
        
        Returns:
            Dictionary mapping category names to lists of item names
        """
        return AVAILABLE_ITEMS
    
    def validate_seed(self, new_value):
        """Validate the seed input
        
        Args:
            new_value: New value to validate
            
        Returns:
            True if valid, False otherwise
        """
        # Allow empty (will default to random) or "random"
        if new_value == "" or new_value.lower() == "random":
            return True
        
        # Otherwise only allow valid seed characters and max length 8
        seed_dictionary = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return len(new_value) <= 8 and all(char in seed_dictionary for char in new_value.upper())
    
    def on_config_name_changed(self, *args):
        """Handle configuration name changes"""
        self.controller.set_config_name(self.config_name_var.get())
    
    def on_deck_changed(self, event=None):
        """Handle deck selection changes"""
        self.controller.set_setting('deck', self.deck_var.get())
    
    def on_stake_changed(self, event=None):
        """Handle stake selection changes"""
        self.controller.set_setting('stake', self.stake_var.get())
    
    def on_thread_groups_changed(self, event=None):
        """Handle thread groups selection changes"""
        self.controller.set_setting('thread_groups', self.thread_groups_var.get())
    
    def on_random_seed(self):
        """Generate a random seed of 1-8 uppercase letters/numbers"""
        import random
        seed_dictionary = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        length = random.randint(1, 8)
        random_seed = ''.join(random.choice(seed_dictionary) for _ in range(length))
        self.starting_seed_entry.delete(1.0, tk.END)
        self.starting_seed_entry.insert(tk.END, random_seed)
    
    def on_number_of_seeds_changed(self, event=None):
        """Handle number of seeds selection changes"""
        self.controller.set_setting('number_of_seeds', self.number_of_seeds_var.get())
    
    def on_save_direct(self):
        """Save directly to {config_name}.ouija.json in the config directory, no prompt."""
        config_name = self.config_name_var.get().strip()
        if not config_name:
            self.set_status("Please enter a configuration name before saving.")
            return
        file_name = config_name.lower().replace(" ", "_") + ".ouija.json"
        file_path = os.path.join(self.controller.config_model.CONFIG_DIR, file_name)
        self.controller.save_config(file_path)
    
    def on_save_as(self):
        """Prompt user for file path, pre-filling with config name, and save there."""
        config_name = self.config_name_var.get().strip()
        if not config_name:
            self.set_status("Please enter a configuration name before saving.")
            return
        file_name = config_name.lower().replace(" ", "_") + ".ouija.json"
        file_path = filedialog.asksaveasfilename(
            initialdir=self.controller.config_model.CONFIG_DIR,
            initialfile=file_name,
            defaultextension=".ouija.json",
            filetypes=[("Ouija JSON files", "*.ouija.json"), ("All files", "*.*")]
        )
        if file_path:
            self.controller.save_config(file_path)
    
    def on_load_config(self):
        """Load a configuration"""
        file_path = filedialog.askopenfilename(
            initialdir=self.controller.config_model.CONFIG_DIR,
            title="Load Configuration",
            filetypes=[("Ouija JSON files", "*.ouija.json"), ("All files", "*.*")]
        )
        
        if file_path:
            self.controller.load_config(file_path)
            self.controller.refresh_results()
    
    def on_add_need(self, category):
        """Add a need from the selected category"""
        result = ItemSelectorDialog.show_dialog(self.root, f"Select Need {category}", category, True)
        if result:
            # If the ante is set to 0, add as a want instead
            if result["desireByAnte"] == 0:
                self.controller.add_want(result)
            else:
                self.controller.add_need(result)
    
    def on_add_want(self, category):
        """Add a want from the selected category"""
        result = ItemSelectorDialog.show_dialog(self.root, f"Select Want {category}", category, False)
        if result:
            self.controller.add_want(result)
    
    def on_remove_selected(self):
        """Remove the selected criterion"""
        selected_indices = self.criteria_list.curselection()
        if selected_indices:
            self.controller.remove_criterion(selected_indices[0])
    
    def on_clear_all(self):
        """Clear all criteria"""
        if messagebox.askyesno("Confirm", "Are you sure you want to clear all criteria?"):
            self.controller.clear_all_criteria()
    
    def on_randomize(self):
        """Generate random criteria"""
        if messagebox.askyesno("Confirm", "This will clear your current criteria and create random ones. Continue?"):
            self.controller.randomize_criteria()
    
    def on_run_search(self):
        """Start or stop the search process"""
        if not hasattr(self, 'search_running'):
            self.search_running = False
            self.start_time = None

        if not self.search_running:
            self.search_running = True
            self.start_time = time.time()
            self.run_button.config(text="STOP SEARCH", bg=RED)
            self.controller.start_search()
        else:
            self.search_running = False
            self.run_button.config(text="Let Jimbo Cook!", bg=BLUE)
            self.controller.stop_search()
            if self.start_time:
                elapsed = time.time() - self.start_time
                self.write_to_console(f"Search stopped. Elapsed time: {elapsed:.2f} seconds\n")
    
    def on_closing(self):
        """Handle window closing event"""
        self.controller.cleanup()
        self.root.destroy()

    def update_status_bar_periodically(self):
        if self.search_running and self._search_start_time is not None:
            elapsed = int(time.time() - self._search_start_time)
            hours = elapsed // 3600
            minutes = (elapsed % 3600) // 60
            seconds = elapsed % 60
            msg = f"Searching for {hours}h {minutes}m {seconds}s... Found {self._search_results_count} scored seeds!"
        else:
            msg = "Ready"
        self.status_bar.set_status(msg)
        self._status_update_id = self.root.after(self._status_update_interval_ms, self.update_status_bar_periodically)

    def update_config_display(self):
        """Update the UI with current configuration settings"""
        # Example: update config name, deck, stake, etc.
        self.config_name_var.set(self.controller.get_config_name())
        self.deck_var.set(self.controller.get_setting('deck', 'Red Deck'))
        self.stake_var.set(self.controller.get_setting('stake', 'Black Stake'))
        self.thread_groups_var.set(self.controller.get_setting('thread_groups', '112'))
        self.starting_seed_var.set(self.controller.get_setting('starting_seed', 'random'))
        self.number_of_seeds_var.set(self.controller.get_setting('number_of_seeds', 'Default (All Seeds)'))
        self.controller.refresh_results()

    def update_criteria_display(self):
        """Update the criteria list with current needs and wants"""
        # Clear current list
        self.criteria_list.delete(0, tk.END)
        # Add needs
        for need in self.controller.config_model.needs_list:
            display_text = f"NEED: {get_display_name(need['value'])}"
            if "desireByAnte" in need and need["desireByAnte"] > 0:
                display_text += f" by Ante {need['desireByAnte']}"
            if "jokeredition" in need and need["jokeredition"] != "No_Edition":
                display_text += f" ({need['jokeredition']})"
            self.criteria_list.insert(tk.END, display_text)
        # Add wants
        for want in self.controller.config_model.wants_list:
            display_text = f"WANT: {get_display_name(want['value'])}"
            if "jokeredition" in want and want["jokeredition"] != "No_Edition":
                display_text += f" ({want['jokeredition']})"
            self.criteria_list.insert(tk.END, display_text)
        self.controller.refresh_results()