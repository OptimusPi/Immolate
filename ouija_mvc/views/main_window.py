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
import json

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
        self._search_start_time = None
        
        # Define table font attributes early
        self.table_font_family = "m6x11"
        self.table_font_size = 13  # Updated font size

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
        self._debounce_interval_ms = 1000
        self._status_update_id = None
        self._last_results_count = 0
        self._search_results_count = 0
    
    def setup_font(self):
        """Set up custom font for the application with slightly larger size"""
        # Use system monospace font as fallback if m6x11 not available
        self.custom_font = font.nametofont("TkDefaultFont")
        self.custom_font.configure(family="m6x11", size=18)
        self.root.option_add("*Font", self.custom_font)
        
        # Define table font attributes with slightly larger size
        self.table_font_family = "m6x11"
        # Increase table font size from 12 to 13
        self.table_font_size = 16
    
    def create_layout(self):
        """Create the main layout frames with better proportioning"""
        # Main container frame
        self.main_container = tk.Frame(self.root, bg=BACKGROUND)
        self.main_container.pack(fill=tk.BOTH, expand=True, padx=2, pady=2)
        
        # Top frame (for control panels) - allow it to expand
        self.settings_frame = tk.Frame(self.main_container, bg=BACKGROUND)
        self.settings_frame.pack(fill=tk.BOTH, expand=True, padx=2, pady=2)
        
        # Create columns within the settings_frame
        self.config_column_frame = tk.Frame(self.settings_frame, bg=BACKGROUND, width=280) 
        self.config_column_frame.pack_propagate(False)
        self.config_column_frame.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=2)

        self.deck_column_frame = tk.Frame(self.settings_frame, bg=BACKGROUND, width=200) # Adjusted width
        self.deck_column_frame.pack_propagate(False)
        self.deck_column_frame.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=2)
        
        # Bottom frame (for results table) - take more vertical space
        self.bottom_frame = tk.Frame(self.main_container, bg=BACKGROUND)
        self.bottom_frame.pack(fill=tk.BOTH, expand=True, padx=2, pady=2)
    
    def create_config_section(self):
        """Create the configuration section with a more streamlined layout"""
        # self.left_frame is replaced by self.config_column_frame defined in create_layout
        
        # ===== Save/Load Frame =====
        self.config_frame = tk.LabelFrame(self.config_column_frame, text="Configuration", 
                                        padx=4, pady=4, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.config_frame.pack(fill=tk.X, expand=False, padx=2, pady=2)
        
        # Config name entry
        self.config_name_var = tk.StringVar()
        self.config_name_entry = tk.Entry(self.config_frame, textvariable=self.config_name_var, font=("m6x11", 13))
        self.config_name_entry.pack(fill=tk.X, pady=2)
        self.config_name_var.trace_add("write", self.on_config_name_changed)
        
        # Button rows
        button_frame = tk.Frame(self.config_frame, bg=BACKGROUND)
        button_frame.pack(fill=tk.X, pady=2)
        
        self.save_button = tk.Button(button_frame, text="Save", 
                                   command=self.on_save_direct, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12))
        self.save_button.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0,1))
        
        self.save_as_button = tk.Button(button_frame, text="Save As", 
                                      command=self.on_save_as, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12))
        self.save_as_button.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(1,1))
        
        self.load_button = tk.Button(button_frame, text="Load", 
                                   command=self.on_load_config, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12))
        self.load_button.pack(side=tk.RIGHT, expand=True, fill=tk.X, padx=(1,0))
        
        # ===== Search Settings Frame =====
        self.search_settings_frame = tk.LabelFrame(self.config_column_frame, text="Search Settings", 
                                                 padx=4, pady=4, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.search_settings_frame.pack(fill=tk.X, expand=True, padx=2, pady=2)
        
        # Create a grid layout for more compact controls
        row = 0

        # Deck label and dropdown
        tk.Label(self.search_settings_frame, text="Deck:", 
                 bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        self.deck_var = tk.StringVar()
        self.deck_dropdown = ttk.Combobox(self.search_settings_frame,
                                           textvariable=self.deck_var, state="readonly",
                                           font=("m6x11", 12))
        self.deck_dropdown['values'] = AVAILABLE_ITEMS["Decks"]
        self.deck_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.deck_dropdown.bind("<<ComboboxSelected>>", self.on_deck_changed)
        row += 1

        # Stake label and dropdown
        tk.Label(self.search_settings_frame, text="Stake:", 
                 bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        self.stake_var = tk.StringVar()
        self.stake_dropdown = ttk.Combobox(self.search_settings_frame,
                                            textvariable=self.stake_var, state="readonly",
                                            font=("m6x11", 12))
        self.stake_dropdown['values'] = AVAILABLE_ITEMS["Stakes"]
        self.stake_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.stake_dropdown.bind("<<ComboboxSelected>>", self.on_stake_changed)
        row += 1

        # Seed label and entry
        tk.Label(self.search_settings_frame, text="Starting Seed:", 
                 bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        seed_frame = tk.Frame(self.search_settings_frame, bg=BACKGROUND)
        seed_frame.grid(row=row, column=1, sticky="ew", pady=2)
        self.starting_seed_var = tk.StringVar()

        # Adjust the button and frame to ensure proper width
        seed_frame.columnconfigure(0, weight=1)
        seed_frame.columnconfigure(1, weight=0)

        self.starting_seed_entry = tk.Entry(seed_frame, textvariable=self.starting_seed_var, 
                                            font=("m6x11", 12))
        self.starting_seed_entry.grid(row=0, column=0, sticky="ew")
        random_seed_button = tk.Button(seed_frame, text="🎲", bg=GREEN, fg=LIGHT_TEXT,
                                       command=self.on_random_seed, font=("m6x11", 12), width=6)
        random_seed_button.grid(row=0, column=1, padx=(8, 0))
        row += 1

        # Search size dropdown
        tk.Label(self.search_settings_frame, text="Search Size:", 
               bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        
        self.number_of_seeds_var = tk.StringVar()
        self.number_of_seeds_dropdown = ttk.Combobox(self.search_settings_frame, 
                                                   textvariable=self.number_of_seeds_var, state="readonly", 
                                                   font=("m6x11", 12))
        self.number_of_seeds_dropdown['values'] = ["All", "1 Single Seed",
                                                "100K", "1M", "100M", "1B"]
        self.number_of_seeds_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.number_of_seeds_dropdown.bind("<<ComboboxSelected>>", self.on_number_of_seeds_changed)
        row += 1
        
        # Thread groups
        tk.Label(self.search_settings_frame, text="Thread Groups:", 
               bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        
        self.thread_groups_var = tk.StringVar()
        self.thread_groups_dropdown = ttk.Combobox(self.search_settings_frame, 
                                                 textvariable=self.thread_groups_var, state="readonly", 
                                                 font=("m6x11", 12))
        self.thread_groups_dropdown['values'] = ["Single", "16", "32", "64", "128", "256"]
        self.thread_groups_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.thread_groups_dropdown.bind("<<ComboboxSelected>>", self.on_thread_groups_changed)
        row += 1

        # Cutoff entry
        tk.Label(self.search_settings_frame, text="Cutoff Score:",
               bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        self.cutoff_var = tk.StringVar()
        self.cutoff_entry = tk.Entry(self.search_settings_frame, textvariable=self.cutoff_var,
                                     font=("m6x11", 12))
        self.cutoff_entry.grid(row=row, column=1, sticky="ew", pady=2)
        self.cutoff_var.trace_add("write", self.on_cutoff_changed)
        row += 1

        # GPU Batch dropdown
        tk.Label(self.search_settings_frame, text="GPU Batch Size:",
               bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        self.gpu_batch_var = tk.StringVar()
        self.gpu_batch_dropdown = ttk.Combobox(self.search_settings_frame,
                                               textvariable=self.gpu_batch_var, state="readonly",
                                               font=("m6x11", 12))
        self.gpu_batch_dropdown['values'] = ["1", "2", "4", "8", "16", "32", "64", "128", "256", "512", "1024", "2048", "4096", "8192"]
        self.gpu_batch_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.gpu_batch_dropdown.bind("<<ComboboxSelected>>", self.on_gpu_batch_changed)
        row += 1
        
        # Configure column weights
        self.search_settings_frame.columnconfigure(1, weight=1)
    
    def create_criteria_section(self):
        """Create the criteria selection section with deck settings included"""
        self.criteria_frame = tk.LabelFrame(self.settings_frame, text="Search Criteria", 
                                          padx=6, pady=6, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.criteria_frame.pack(fill=tk.BOTH, expand=True, side=tk.LEFT, padx=4, pady=4)
        
        # Criteria section - split into left (deck settings) and right (criteria list)
        criteria_left = tk.Frame(self.criteria_frame, bg=BACKGROUND)
        criteria_left.pack(side=tk.LEFT, fill=tk.Y, padx=2)
        
        criteria_right = tk.Frame(self.criteria_frame, bg=BACKGROUND)
        criteria_right.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=2)

        # Criteria buttons in right side
        self.add_criteria_frame = tk.Frame(criteria_right, bg=BACKGROUND)
        self.add_criteria_frame.pack(fill=tk.X, pady=2)
        
        # Add criteria buttons
        tk.Button(self.add_criteria_frame, text="+Joker", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Jokers")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+Tarot", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Tarots")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+Spectral", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Spectrals")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+Tag", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Tags")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+Voucher",
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Vouchers")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+Rank",
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Ranks")).pack(side=tk.LEFT, padx=1)
        tk.Button(self.add_criteria_frame, text="+Suit",
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Suits")).pack(side=tk.LEFT, padx=1)
        
        # Criteria list
        self.criteria_list = tk.Listbox(criteria_right, height=4, bg=DARK_BACKGROUND, fg=LIGHT_TEXT,
                                     selectmode=tk.SINGLE, font=("m6x11", 12))
        self.criteria_list.pack(fill=tk.BOTH, expand=True, padx=2, pady=2)
        
        # Criteria action buttons
        self.criteria_buttons_frame = tk.Frame(criteria_right, bg=BACKGROUND)
        self.criteria_buttons_frame.pack(fill=tk.X, pady=2)
        
        tk.Button(self.criteria_buttons_frame, text="Clear All", 
                command=self.on_clear_all, bg=RED, fg=LIGHT_TEXT, font=("m6x11", 12)).pack(side=tk.RIGHT, padx=1)
        tk.Button(self.criteria_buttons_frame, text="Remove Selected", 
                command=self.on_remove_selected, bg=RED, fg=LIGHT_TEXT, font=("m6x11", 12)).pack(side=tk.RIGHT, padx=1)
    
    def create_run_settings_section(self):
        """Create the run settings and console output section with adjusted width"""
        self.run_settings_frame = tk.LabelFrame(self.settings_frame, text="Run", 
                                              padx=6, pady=6, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        # Make this frame narrower by setting width explicitly and prevent children from resizing it
        self.run_settings_frame.config(width=320) # Adjusted width
        self.run_settings_frame.pack_propagate(False) # Prevent children from resizing this frame
        self.run_settings_frame.pack(fill=tk.Y, expand=False, side=tk.LEFT, padx=4, pady=4) # Changed fill to tk.Y
        
        # Console output at top now
        console_frame = tk.Frame(self.run_settings_frame, bg=BACKGROUND)
        console_frame.pack(fill=tk.BOTH, expand=True)
        
        self.output_text = tk.Text(console_frame, wrap=tk.WORD, height=5,
                                 bg=DARK_BACKGROUND, fg=LIGHT_TEXT, 
                                 font=("m6x11", 13), insertbackground='white')
        self.output_text.pack(fill=tk.BOTH, expand=True)
        
        # Move run button to bottom
        self.run_button = tk.Button(self.run_settings_frame, text="Let Jimbo Cook!", 
                                  command=self.on_run_search, 
                                  bg=BLUE, fg=LIGHT_TEXT, 
                                  font=("m6x11", 16))
        self.run_button.pack(fill=tk.X, pady=(10, 0), padx=5)
    
    def create_results_section(self):
        """Create results table section with more vertical space"""
        self.results_frame = tk.LabelFrame(self.bottom_frame, text="Results", 
                                         padx=4, pady=4, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.results_frame.pack(fill=tk.BOTH, expand=True, padx=2, pady=2)
        
        # Make results table take up more vertical space
        self.pt = Table(self.results_frame, dataframe=pd.DataFrame(),
                       showtoolbar=False, showstatusbar=False,
                       font=self.table_font_family,
                       fontsize=self.table_font_size,
                       headerfont=(self.table_font_family, self.table_font_size))
        
        # Show the table and set it to expand fully
        self.pt.show()
        
        # Set default precision for numeric columns
        if not hasattr(self.pt, 'columnformats'):
            self.pt.columnformats = {}
        self.pt.columnformats['default'] = {'precision': 0}
        
        self.latest_df = None
        self._setup_initial_table()

    def _adjust_table_column_widths(self):
        """Adjusts column widths using pandastable's built-in auto-resize feature."""
        if not hasattr(self.pt, 'model') or self.pt.model is None or \
           not hasattr(self.pt.model, 'df') or self.pt.model.df is None:
            self.pt.redraw()  # Ensure table is drawn if empty
            return

        # Let pandastable handle the column sizing
        self.pt.autoResizeColumns()
        
        # Apply a minimum size to ensure headers aren't cut off
        if hasattr(self.pt, 'currentwidths') and self.pt.model.df is not None:
            # Redraw the table to apply changes
            self.pt.redraw()

    def _setup_initial_table(self):
        """Set up the results table to refresh immediately and then every 1000ms."""
        def refresh_loop():
            self.refresh_results_table()
            self.root.after(1000, refresh_loop)
        # Call once immediately, then start the loop
        self.refresh_results_table()

    def update_results_table(self, dataframe):
        self.latest_df = dataframe
        if dataframe is not None:
            # Ensure numeric columns display as integers
            for col in dataframe.columns:
                if col != 'Seed' and pd.api.types.is_numeric_dtype(dataframe[col]):
                    # Set format for this column to show integers (no decimals)
                    if hasattr(self.pt, 'columnformats'):
                        if col not in self.pt.columnformats:
                            self.pt.columnformats[col] = {}
                        self.pt.columnformats[col]['precision'] = 0
            
            self.pt.model.df = dataframe
        else:
            self.pt.model.df = pd.DataFrame()  # Ensure empty df if None
            
        self.pt.redraw()  # Redraw with new data (or empty)
        self._adjust_table_column_widths()  # Adjust widths
        self._search_results_count = len(dataframe) if dataframe is not None else 0
    
    def refresh_results_table(self):
        """Reload the results table from the database and update the UI."""
        from ouija_mvc.models.database_model import DatabaseModel
        db_model = DatabaseModel()
        try:
            with open('ouija_user.conf', 'r') as f:
                user_conf = json.load(f)
            config_path = user_conf.get('last_config_path')
        except Exception:
            config_path = None
            
        if config_path and db_model.connect(config_path) and db_model.table_exists():
            df = db_model.get_dataframe()
            if df is not None and (self.latest_df is None or not df.equals(self.latest_df)):
                self.update_results_table(df)
                
                # Update metrics if search is running
                if self._search_start_time is not None:
                    elapsed = time.time() - self._search_start_time
                    seeds_per_sec = self._search_results_count / elapsed if elapsed > 0 else 0
                    self.set_metrics(f"$clock$ {seeds_per_sec:.0f}/s")
        else:
            if self.latest_df is not None:
                self.update_results_table(pd.DataFrame())

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
    
    def set_metrics(self, text):
        """Set metrics text in the status bar (right side)
        
        Args:
            text: Metrics text to display
        """
        # Replace $clock$ with ⏱️ for display
        if text and "$clock$" in text:
            text = text.replace("$clock$", "⏱️")
        self.status_bar.set_metrics(text)
    
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
    
    def on_cutoff_changed(self, *args):
        """Handle cutoff score changes"""
        self.controller.set_setting('cutoff', self.cutoff_var.get())

    def on_gpu_batch_changed(self, event=None):
        """Handle GPU batch size selection changes"""
        self.controller.set_setting('gpu_batch', self.gpu_batch_var.get())

    def on_random_seed(self):
        """Set the search seed to random, ouija.exe handles this"""
        self.starting_seed_entry.delete(0, tk.END)
        self.starting_seed_entry.insert(0, "random")
    
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
            self.update_config_display()    # Add this to refresh config UI elements
            self.update_criteria_display()  # Add this to refresh criteria list
            self.controller.refresh_results()      # Refresh results table once after UI updates
    
    def on_add_need(self, category):
        """Add a need from the selected category"""
        # The True argument indicates to the dialog that the initial context is a 'Need'
        result = ItemSelectorDialog.show_dialog(self.root, f"Select Need: {category}", category, True)
        if result:
            item_payload = result["payload"]

            if result["is_need"]:
                # If it's a Rank or Suit Need, explicitly set desireByAnte to 1 as per requirements
                if result["type"] == "RankOrSuit":
                    item_payload["desireByAnte"] = 1
                # For Standard needs, desireByAnte should already be in item_payload if ante > 0
                self.controller.add_need(item_payload)
            else:
                # If is_need is False (either Rank/Suit selected as Want, or Standard item with Ante 0)
                # it's treated as a Want. Ensure desireByAnte is not in payload for wants if it was 0.
                if "desireByAnte" in item_payload and item_payload["desireByAnte"] == 0:
                    del item_payload["desireByAnte"]
                self.controller.add_want(item_payload)
            
            self.update_criteria_display() # Refresh list after adding
    
    def on_add_want(self, category):
        """Add a want from the selected category"""
        # The False argument indicates to the dialog that the initial context is a 'Want'
        result = ItemSelectorDialog.show_dialog(self.root, f"Select Want: {category}", category, False)
        if result:
            item_payload = result["payload"]
            # Ensure desireByAnte is not part of a want payload, 
            # especially if it might have been added and set to 0 by the dialog for standard items.
            if "desireByAnte" in item_payload:
                del item_payload["desireByAnte"]
            self.controller.add_want(item_payload)
            self.update_criteria_display() # Refresh list after adding
    
    def on_remove_selected(self):
        """Remove the selected criterion"""
        selected_indices = self.criteria_list.curselection()
        if selected_indices:
            self.controller.remove_criterion(selected_indices[0])
    
    def on_clear_all(self):
        """Clear all criteria"""
        if messagebox.askyesno("Confirm", "Are you sure you want to clear all criteria?"):
            self.controller.clear_all_criteria()
    
    def on_run_search(self):
        """Start or stop the search process"""
        if not hasattr(self, 'search_running'):
            self.search_running = False
            self.start_time = None

        if not self.search_running:
            # Get the current seed value
            seed_value = self.starting_seed_var.get().strip()
            if not seed_value or seed_value.lower() == 'random':
                seed_value = 'random'
            
            self.search_running = True
            self.start_time = time.time()
            self.run_button.config(text="STOP SEARCH", bg=RED)
            self.controller.set_setting('starting_seed', seed_value)  # Update the controller
            self.controller.run_search()
        else:
            self.search_running = False
            self.run_button.config(text="Let Jimbo Cook!", bg=BLUE)
            self.controller.stop_search()
            if self.start_time:
                elapsed = time.time() - self.start_time
                self.write_to_console(f"Search stopped. Elapsed time: {elapsed:.2f} seconds\n")
    
    def on_closing(self):
        """Handle window closing event"""
        # Make sure we stop all search processes first
        if self.search_running:
            self.controller.stop_search()
        
        # Then do the general cleanup
        self.controller.cleanup()
        
        # Finally destroy the root window
        self.root.destroy()

    def update_config_display(self):
        """Update the UI with current configuration settings"""
        # Example: update config name, deck, stake, etc.
        self.config_name_var.set(self.controller.get_config_name())
        self.deck_var.set(self.controller.get_setting('deck', 'Red Deck'))
        self.stake_var.set(self.controller.get_setting('stake', 'Black Stake'))
        self.thread_groups_var.set(self.controller.get_setting('thread_groups', '32'))
        self.starting_seed_var.set(self.controller.get_setting('starting_seed', 'random'))
        self.number_of_seeds_var.set(self.controller.get_setting('number_of_seeds', 'All'))
        self.cutoff_var.set(self.controller.get_setting('cutoff', ''))
        self.gpu_batch_var.set(self.controller.get_setting('gpu_batch', '16'))

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

    def update_deck_Settings_display(self):
        """Update the deck settings display with current values"""
        self.deck_var.set(self.controller.get_setting('deck', 'Red Deck'))
        self.stake_var.set(self.controller.get_setting('stake', 'Black Stake'))