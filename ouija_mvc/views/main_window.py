"""
Main Window View for Ouija Seed Finder Application
"""
import os
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, font
import pandas as pd
import time
from pandastable import Table
import sys
import json
import random  # for random fun/naughty words

# Import from our own modules
from .dialogs import ItemSelectorDialog
from ..utils.ui_utils import (
    add_tooltip, StatusBar, ScrollableFrame, 
    BLUE, RED, GREEN, BACKGROUND, DARK_BACKGROUND, LIGHT_TEXT
)
from ..utils.game_data import AVAILABLE_ITEMS, get_display_name
from ouija_mvc.models.database_model import DatabaseModel

# Define word lists
FUNNY_WORDS = ["PIE", "CHEAT", "POO", "POOP", "69", "420","FART", "BUM", "BUTT", "BOOB", "NERD", "DORK", "RAD", "COOL", "BEAN", "LIPS"]
NAUGHTY_WORDS = ["FUCK", "SHIT", "CUNT", "TWAT", "DICK", "PRICK", "SLUT", "WHORE", "CLIT", "ASS", "PISS", "69", "SEX", "420", "BLOW", "METH", "CRACK", "PUSSY", "COCK", "VAG", "FAG", "GAY"]
# Combine for Funny List mode if desired, or keep separate for selection
COMBINED_FUNNY_LIST = FUNNY_WORDS + NAUGHTY_WORDS

friendly_template_names = {
    "Default": "ouija_template",
    "Erratic Ranks": "ouija_template_erratic_ranks",
    "Anaglyph": "ouija_template_anaglyph",
    "Natural Negatives": "ouija_template_negatives"
}


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
        # Advanced settings variables (always present)
        self.thread_groups_var = tk.StringVar()
        self.gpu_batch_var = tk.StringVar()
        self.cutoff_var = tk.StringVar()
        self.fun_word_entry_var = tk.StringVar()
        self.search_type_var = tk.StringVar(value="Default") # Ensure search_type_var is initialized here
        # Define table font attributes early
        self.table_font_family = "m6x11"
        self.table_font_size = 13  # Updated font size

        # Register this view with the controller
        controller.register_view(self)
          # Apply custom font
        self.setup_font()
        
        # Create status bar FIRST so it gets allocated space before main content
        self.status_bar = StatusBar(self.root)
        self.status_bar.pack(side=tk.BOTTOM, fill=tk.X)
        
        # Create main layout frames
        self.create_layout()
        
        # Create widgets in each section
        self.create_deck_settings_section()    
        self.create_criteria_section()
        self.create_results_section()
        
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
        """Create the main layout with proper proportions"""
        # Main container frame with proper padding
        self.main_container = tk.Frame(self.root, bg=BACKGROUND)
        self.main_container.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # Create top section with FIXED HEIGHT - constrain it properly
        self.settings_frame = tk.Frame(self.main_container, bg=BACKGROUND, height=300)
        self.settings_frame.pack(side=tk.TOP, fill=tk.X, expand=False, pady=(0, 5))
        self.settings_frame.pack_propagate(False)  # CRITICAL: Prevent expansion

        # Create three equal columns in the top section with padding between them
        self.left_column = tk.Frame(self.settings_frame, bg=BACKGROUND)
        self.left_column.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 5))

        self.middle_column = tk.Frame(self.settings_frame, bg=BACKGROUND)
        self.middle_column.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)

        self.right_column = tk.Frame(self.settings_frame, bg=BACKGROUND)
        self.right_column.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(5, 0))

        # Place config section at the top of the right column
        self.create_config_section(parent=self.right_column)
        # Then place the run/console section below it
        self.create_run_settings_section(parent=self.right_column)

        # Bottom section - THIS gets all the remaining space
        self.bottom_frame = tk.Frame(self.main_container, bg=BACKGROUND)
        self.bottom_frame.pack(side=tk.BOTTOM, fill=tk.BOTH, expand=True)

        # Remove the window resize handler since we want natural behavior
        # self.root.bind("<Configure>", self._on_window_resize)
    
    # Remove the _on_window_resize method entirely since we don't need it
    # def _on_window_resize(self, event):
    #     ...existing code...
    
    def create_config_section(self, parent=None):
        """Create the configuration section with optimized spacing"""
        if parent is None:
            parent = self.bottom_frame
        self.config_frame = tk.LabelFrame(parent, text="Save/Load Configuration", 
                                        padx=5, pady=5, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.config_frame.pack(fill=tk.X, expand=False, padx=2, pady=(2, 5), side=tk.TOP)
        
        # Config name entry with better padding
        self.config_name_var = tk.StringVar()
        self.config_name_entry = tk.Entry(self.config_frame, textvariable=self.config_name_var, font=("m6x11", 13))
        self.config_name_entry.pack(fill=tk.X, pady=5)
        self.config_name_var.trace_add("write", self.on_config_name_changed)
        
        # Button rows with improved spacing
        button_frame = tk.Frame(self.config_frame, bg=BACKGROUND)
        button_frame.pack(fill=tk.X, pady=5)
        
        self.save_button = tk.Button(button_frame, text="Save", 
                                   command=self.on_save_direct, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12))
        self.save_button.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0, 5))
        
        self.save_as_button = tk.Button(button_frame, text="Save As", 
                                      command=self.on_save_as, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12))
        self.save_as_button.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=5)
        
        self.load_button = tk.Button(button_frame, text="Load", 
                                   command=self.on_load_config, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12))
        self.load_button.pack(side=tk.RIGHT, expand=True, fill=tk.X, padx=(5, 0))
        
    def create_deck_settings_section(self):
        """Create the deck settings section (formerly search settings)"""
        self.deck_settings_frame = tk.LabelFrame(self.left_column, text="Deck Settings", 
                                                 padx=2, pady=2, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.deck_settings_frame.pack(fill=tk.BOTH, expand=True, padx=1, pady=1)
        row = 0
        # Deck label and dropdown
        tk.Label(self.deck_settings_frame, text="Deck:", 
                 bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        self.deck_var = tk.StringVar()
        self.deck_dropdown = ttk.Combobox(self.deck_settings_frame,
                                           textvariable=self.deck_var, state="readonly",
                                           font=("m6x11", 12))
        self.deck_dropdown['values'] = AVAILABLE_ITEMS["Decks"]
        self.deck_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.deck_dropdown.bind("<<ComboboxSelected>>", self.on_deck_changed)
        row += 1
        # Stake label and dropdown
        tk.Label(self.deck_settings_frame, text="Stake:", 
                 bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        self.stake_var = tk.StringVar()
        self.stake_dropdown = ttk.Combobox(self.deck_settings_frame,
                                            textvariable=self.stake_var, state="readonly",
                                            font=("m6x11", 12))
        self.stake_dropdown['values'] = AVAILABLE_ITEMS["Stakes"]
        self.stake_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.stake_dropdown.bind("<<ComboboxSelected>>", self.on_stake_changed)
        row += 1
        # Seed label and entry
        self.seed_row = row  # Save for show/hide
        tk.Label(self.deck_settings_frame, text="Start Seed:", 
                 bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12), name="seed_label").grid(row=row, column=0, sticky="w", pady=2)
        seed_frame = tk.Frame(self.deck_settings_frame, bg=BACKGROUND, name="seed_frame")
        seed_frame.grid(row=row, column=1, sticky="ew", pady=2)
        self.starting_seed_var = tk.StringVar()
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
        tk.Label(self.deck_settings_frame, text="Search Size:", 
               bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        self.number_of_seeds_var = tk.StringVar()
        self.number_of_seeds_dropdown = ttk.Combobox(self.deck_settings_frame, 
                                                   textvariable=self.number_of_seeds_var, state="readonly", 
                                                   font=("m6x11", 12))
        self.number_of_seeds_dropdown['values'] = ["All", "1 Single Seed",
                                                "1K", "100K", "1M", "100M", "1B", "10B", "100B"]
        self.number_of_seeds_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.number_of_seeds_dropdown.bind("<<ComboboxSelected>>", self.on_number_of_seeds_changed)
        row += 1
        # Template selector dropdown
        tk.Label(self.deck_settings_frame, text="Template:",
               bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 12)).grid(row=row, column=0, sticky="w", pady=2)
        self.template_var = tk.StringVar()
        self.template_dropdown = ttk.Combobox(
            self.deck_settings_frame,
            textvariable=self.template_var,
            state="readonly",
            font=("m6x11", 12)
        )
        self.template_dropdown['values'] = list(friendly_template_names.keys())
        self.template_dropdown.grid(row=row, column=1, sticky="ew", pady=2)
        self.template_dropdown.bind("<<ComboboxSelected>>", self.on_template_changed)
        row += 1
        self.deck_settings_frame.columnconfigure(1, weight=1)
        for r in range(row+1):
            self.deck_settings_frame.grid_rowconfigure(r, pad=1)

    def create_criteria_section(self):
        """Create the criteria selection section with improved spacing"""
        self.criteria_frame = tk.LabelFrame(self.middle_column, text="Customize Filter", 
                                          padx=5, pady=5, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.criteria_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
          # Criteria section - split into left (deck settings) and right (criteria list)
        criteria_left = tk.Frame(self.criteria_frame, bg=BACKGROUND)
        criteria_left.pack(side=tk.LEFT, fill=tk.Y, padx=5)
        
        criteria_right = tk.Frame(self.criteria_frame, bg=BACKGROUND)
        criteria_right.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=5)
        
        # Criteria buttons in right side
        self.add_criteria_frame = tk.Frame(criteria_right, bg=BACKGROUND)
        self.add_criteria_frame.pack(fill=tk.X, pady=5)
        
        # Add criteria buttons
        tk.Button(self.add_criteria_frame, text="+Joker", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Jokers")).pack(side=tk.LEFT, padx=4)
        tk.Button(self.add_criteria_frame, text="+Tarot", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Tarots")).pack(side=tk.LEFT, padx=4)
        tk.Button(self.add_criteria_frame, text="+Spectral", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Spectrals")).pack(side=tk.LEFT, padx=4)
        tk.Button(self.add_criteria_frame, text="+Tag", 
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Tags")).pack(side=tk.LEFT, padx=4)
        tk.Button(self.add_criteria_frame, text="+Voucher",
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Vouchers")).pack(side=tk.LEFT, padx=4)
        tk.Button(self.add_criteria_frame, text="+Rank",
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Ranks")).pack(side=tk.LEFT, padx=4)
        tk.Button(self.add_criteria_frame, text="+Suit",
                bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12),
                command=lambda: self.on_add_need("Suits")).pack(side=tk.LEFT, padx=4)
        
        # Criteria list
        self.criteria_list = tk.Listbox(criteria_right, bg=DARK_BACKGROUND, fg=LIGHT_TEXT,
                                     selectmode=tk.SINGLE, font=("m6x11", 12))
        self.criteria_list.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        # Criteria action buttons
        self.criteria_buttons_frame = tk.Frame(criteria_right, bg=BACKGROUND)
        self.criteria_buttons_frame.pack(fill=tk.X, pady=5)
        
        tk.Button(self.criteria_buttons_frame, text="Clear All", 
                command=self.on_clear_all, bg=RED, fg=LIGHT_TEXT, font=("m6x11", 12)).pack(side=tk.RIGHT, padx=5)
        tk.Button(self.criteria_buttons_frame, text="Remove Selected", 
                command=self.on_remove_selected, bg=RED, fg=LIGHT_TEXT, font=("m6x11", 12)).pack(side=tk.RIGHT, padx=5)
        tk.Button(self.criteria_buttons_frame, text="Edit Selected", 
                command=self.on_edit_selected, bg=BLUE, fg=LIGHT_TEXT, font=("m6x11", 12)).pack(side=tk.RIGHT, padx=5)
    
    def create_run_settings_section(self, parent=None):
        """Create the run settings section with the button properly positioned and advanced settings dialog"""
        if parent is None:
            parent = self.right_column
        self.run_settings_frame = tk.LabelFrame(parent, text="Run", 
                                              padx=3, pady=3, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.run_settings_frame.pack(fill=tk.BOTH, expand=False, padx=1, pady=1)  # Not so tall
        run_container = tk.Frame(self.run_settings_frame, bg=BACKGROUND)
        run_container.pack(fill=tk.BOTH, expand=True)
        run_container.grid_rowconfigure(0, weight=1)
        run_container.grid_rowconfigure(1, weight=0)
        run_container.grid_columnconfigure(0, weight=1)
        console_frame = tk.Frame(run_container, bg=BACKGROUND)
        console_frame.grid(row=0, column=0, sticky="nsew", padx=0, pady=0)
        
        self.output_text = tk.Text(console_frame, wrap=tk.WORD,
                                 bg=DARK_BACKGROUND, fg=LIGHT_TEXT, 
                                 font=("m6x11", 13), insertbackground='white')
        self.output_text.pack(fill=tk.BOTH, expand=True, padx=0, pady=0)
        
        # Button row with Run and Gear
        button_frame = tk.Frame(run_container, bg=BACKGROUND, height=50)
        button_frame.grid(row=1, column=0, sticky="sew", padx=0, pady=(5,0))
        button_frame.grid_propagate(False)
        # Run button        
        self.run_button = tk.Button(button_frame, text="Let Jimbo Cook!",
                                  command=self.on_run_search, 
                                  bg=BLUE, fg=LIGHT_TEXT, 
                                  font=("m6x11", 16))
        self.run_button.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Gear button for advanced settings
        self.advanced_button = tk.Button(button_frame, text="⚙",
                                         command=self.open_advanced_settings_dialog, 
                                         bg=BLUE, fg=LIGHT_TEXT, 
                                         font=("m6x11", 16), width=4,
                                         takefocus=False, cursor="hand2")
        self.advanced_button.pack(side=tk.LEFT, padx=(8,0), pady=0)
        
    def create_results_section(self):
        """Create results table section"""
        self.results_frame = tk.LabelFrame(self.bottom_frame, text="Results", 
                                         padx=5, pady=5, bg=BACKGROUND, fg=LIGHT_TEXT, font=("m6x11", 14))
        self.results_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
          # Add Refresh/Delete Everything buttons
        button_row = tk.Frame(self.results_frame, bg=BACKGROUND)
        button_row.pack(fill=tk.X, pady=(0, 5))
        tk.Button(button_row, text="Refresh", bg=GREEN, fg=LIGHT_TEXT, font=("m6x11", 12), width=10, 
                 command=self.on_refresh_results).pack(side=tk.LEFT, padx=(0,4))
        tk.Button(button_row, text="Delete Everything", bg=RED, fg=LIGHT_TEXT, font=("m6x11", 12), width=16,
                 command=self.on_delete_all_results).pack(side=tk.LEFT, padx=(4,0))
        
        # Create a dedicated container frame for the table to isolate grid geometry manager
        table_container = tk.Frame(self.results_frame, bg=BACKGROUND)
        table_container.pack(fill=tk.BOTH, expand=True)
        
        # Create the table in the dedicated container (pandastable uses grid internally)
        self.pt = Table(table_container, dataframe=pd.DataFrame(),
                       showtoolbar=False, showstatusbar=False,
                       font=self.table_font_family,
                       fontsize=self.table_font_size,
                       headerfont=(self.table_font_family, self.table_font_size))
        self.pt.show()

        self.latest_df = None
        self._setup_initial_table()

    def _adjust_table_column_widths(self):
        """Adjusts column widths based on header names rather than content."""
        if not hasattr(self.pt, 'model') or self.pt.model is None or \
           not hasattr(self.pt.model, 'df') or self.pt.model.df is None:
            self.pt.redraw()
            return

        # NUCLEAR OPTION: Override ALL of pandastable's width settings
        if self.pt.model.df is not None and len(self.pt.model.df.columns) > 0:
            # Force disable ALL auto-sizing mechanisms
            self.pt.autoresizecols = 0
            if hasattr(self.pt, 'autoResizeColumns'):
                self.pt.autoResizeColumns = False
            
            new_widths = {}
            for col in self.pt.model.df.columns:
                # Calculate width based on header name length
                header_width = len(col) * 10  # pixels per character
                min_width = 80   # Minimum column width
                max_width = 200  # Maximum column width
                
                calculated_width = max(min_width, min(header_width, max_width))
                new_widths[col] = calculated_width
                
                # Set in EVERY possible width storage location
                if hasattr(self.pt, 'columnwidths'):
                    self.pt.columnwidths[col] = calculated_width
                if hasattr(self.pt, 'colwidths'):
                    self.pt.colwidths[col] = calculated_width
                if hasattr(self.pt, 'col_positions'):
                    # Force update column positions
                    try:
                        col_index = list(self.pt.model.df.columns).index(col)
                        if col_index < len(self.pt.col_positions):
                            # Update the actual column position
                            if col_index > 0:
                                self.pt.col_positions[col_index] = self.pt.col_positions[col_index-1] + calculated_width
                            else:
                                self.pt.col_positions[col_index] = calculated_width
                    except:
                        pass
            
            # Force manual recalculation of ALL column positions
            if hasattr(self.pt, 'col_positions') and hasattr(self.pt, 'columnwidths'):
                total_width = 0
                for i, col in enumerate(self.pt.model.df.columns):
                    if col in new_widths:
                        if i == 0:
                            self.pt.col_positions[i] = new_widths[col]
                        else:
                            self.pt.col_positions[i] = self.pt.col_positions[i-1] + new_widths[col]
                        total_width += new_widths[col]
            
            # Multiple forced redraws to override stubborn settings
            self.pt.redraw()
            self.root.after(50, lambda: self.pt.redraw())  # Delayed redraw
            
            # Final nuclear option: directly modify the canvas if it exists
            if hasattr(self.pt, 'tablecolheader') and hasattr(self.pt.tablecolheader, 'redraw'):
                self.root.after(100, lambda: self.pt.tablecolheader.redraw())

    def _setup_initial_table(self):
        """Set up the results table to refresh immediately and then every 1000ms."""
        def refresh_loop():
            self.refresh_results_table()
        # Call once immediately, then start the loop
        self.refresh_results_table()

    def update_results_table(self, dataframe):
        self.latest_df = dataframe
        if dataframe is not None:
            # Ensure DataFrame index is continuous for pandastable
            dataframe = dataframe.reset_index(drop=True)
            # Ensure numeric columns display as integers (no decimals)
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

    def on_template_changed(self, event=None):
        selected_friendly_name = self.template_var.get()
        internal_template = friendly_template_names.get(selected_friendly_name, "ouija_template")
        self.controller.set_setting('template', internal_template)

    def on_random_seed(self):
        """Set the search seed to random, ouija.exe handles this"""
        self.starting_seed_entry.delete(0, tk.END)
        self.starting_seed_entry.insert(0, "random")

    def on_random_fun(self):
        """Pick a random PG funny word and set as fun word - Now updates dialog var if dialog is open, else main var."""
        # This method might be deprecated if buttons are only in dialog.
        # For now, assume it might be called if UI elements were elsewhere.
        word = random.choice(FUNNY_WORDS)
        self.fun_word_entry_var.set(word)


    def on_random_naughty(self):
        """Pick a random R-rated naughty word and set as fun word - Updates dialog/main var."""
        # Similar to on_random_fun, may be deprecated.
        word = random.choice(NAUGHTY_WORDS)
        self.fun_word_entry_var.set(word)

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
    
    def on_edit_selected(self):
        """Edit the selected criterion"""
        selected_indices = self.criteria_list.curselection()
        if not selected_indices:
            return
            
        # Get the selected index and determine if it's a need or a want
        index = selected_indices[0]
        needs_count = len(self.controller.config_model.needs_list)
        
        is_need = index < needs_count
        
        # Get the criterion data
        if is_need:
            criterion = self.controller.config_model.needs_list[index]
            category = self.get_category_for_item(criterion["value"])
        else:
            criterion = self.controller.config_model.wants_list[index - needs_count]
            category = self.get_category_for_item(criterion["value"])
        
        # Show the dialog with the existing item data
        result = ItemSelectorDialog.show_dialog(
            self.root,
            f"Edit {'Need' if is_need else 'Want'}: {category}",
            category,
            is_need,
            edit_mode=True,
            existing_item=criterion
        )
        
        if result:
            item_payload = result["payload"]
            
            # Handle Need/Want changes
            if result["is_need"] != is_need:
                # Need/Want type changed - remove old and add new
                self.controller.remove_criterion(index)
                
                if result["is_need"]:
                    self.controller.add_need(item_payload)
                else:
                    # Ensure desireByAnte is removed for wants
                    if "desireByAnte" in item_payload:
                        del item_payload["desireByAnte"]
                    self.controller.add_want(item_payload)
            else:
                # Same type, just update
                self.controller.edit_criterion(index, item_payload)
            
            self.update_criteria_display()
    
    def get_category_for_item(self, item_value):
        """Determine the category for an item based on its value
        
        Args:
            item_value: The internal item value
            
        Returns:
            The category name
        """
        # Check each category for the item value
        from ..utils.game_data import AVAILABLE_ITEMS, get_display_name
        
        item_display_name = get_display_name(item_value)
        
        for category, items in AVAILABLE_ITEMS.items():
            if item_display_name in items:
                return category
        
        # Default to Jokers if not found
        return "Jokers"
    
    def on_clear_all(self):
        """Clear all criteria"""
        if messagebox.askyesno("Confirm", "Are you sure you want to clear all criteria?"):
            self.controller.clear_all_criteria()
    
    def on_run_search(self):
        """Start or stop the search process, passing search type and fun word to controller/config"""
        if not hasattr(self, 'search_running'):
            self.search_running = False
            self.start_time = None

        # Always update config model with current search type and fun word
        search_type = self.search_type_var.get()
        fun_word = self.fun_word_entry_var.get().strip().upper() # This var is now updated from dialog
        self.controller.set_setting('search_type', search_type)
        self.controller.set_setting('fun_word', fun_word) # fun_word is set regardless of mode

        if not self.search_running:
            SEED_CHARACTERS = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            BASE = len(SEED_CHARACTERS)
            MAX_SEED_LEN = 8

            if search_type == 'Default':
                seed_value = self.starting_seed_var.get().strip()
                if not seed_value or seed_value.lower() == 'random':
                    seed_value = 'random'
                self.controller.set_setting('starting_seed', seed_value)

                current_num_seeds_setting = self.number_of_seeds_var.get()
                # Convert known shorthands to numbers if possible, else pass as string (e.g., "All")
                num_seeds_map = {
                    "1K": 1000, "100K": 100000, "1M": 1000000, 
                    "100M": 100000000, "1B": 1000000000, "10B": 10000000000, "100B": 100000000000,
                    "1 Single Seed": 1
                }
                if current_num_seeds_setting in num_seeds_map:
                    self.controller.set_setting('number_of_seeds', num_seeds_map[current_num_seeds_setting])
                elif current_num_seeds_setting.isdigit():
                    self.controller.set_setting('number_of_seeds', int(current_num_seeds_setting))
                else: # Assuming 'All' or other non-numeric/non-mapped
                    self.controller.set_setting('number_of_seeds', current_num_seeds_setting)

            elif search_type == 'Key Word': 
                # fun_word is already fetched and set in config_model above
                if not fun_word:
                    self.write_to_console("Error: Key Word cannot be empty for Key Word search.\\n")
                    messagebox.showerror("Input Error", "Key Word cannot be empty for Key Word search.")
                    return
                
                if not all(char.upper() in SEED_CHARACTERS for char in fun_word):
                    self.write_to_console(f"Error: Key Word '{fun_word}' contains invalid characters.\\n")
                    messagebox.showerror("Input Error", f"Key Word '{fun_word}' contains invalid characters. Only use letters (A-Z) and digits (1-9).")
                    return

                if len(fun_word) > MAX_SEED_LEN:
                    self.write_to_console(f"Error: Key Word '{fun_word}' is too long (max {MAX_SEED_LEN} chars).\\n")
                    messagebox.showerror("Input Error", f"Key Word '{fun_word}' is too long (max {MAX_SEED_LEN} chars).")
                    return
                
                variable_part_len = MAX_SEED_LEN - len(fun_word)
                calculated_start_seed = fun_word + (SEED_CHARACTERS[0] * variable_part_len)
                num_seeds_to_check = BASE ** variable_part_len
                
                self.controller.set_setting('starting_seed', calculated_start_seed)
                self.controller.set_setting('number_of_seeds', num_seeds_to_check)
                
                if hasattr(self, 'number_of_seeds_var'):
                    self.number_of_seeds_var.set(str(num_seeds_to_check))

                self.write_to_console(f"Key Word Mode: Key Word='{fun_word}'.\\n")
                self.write_to_console(f"Calculated Starting Seed: {calculated_start_seed}, Number of Seeds: {num_seeds_to_check}.\\n")

            elif search_type == 'Funny List':
                # Logic for Funny List will be more complex, likely involving multiple calls
                # or a new controller method. For now, just log.
                # The fun_word from the dialog isn't used directly here, but the lists are.
                self.write_to_console("Funny List mode selected. Iteration logic to be handled by controller.\\n")
                # For Funny List, number_of_seeds will be determined per word in the list by the controller.
                # The main UI's number_of_seeds_var might show "Auto" or be disabled.
                # For now, we can set a placeholder or the count for the first word if we were to process one.
                # This part needs to be coordinated with controller changes.
                # For now, let's assume the controller will handle setting appropriate number_of_seeds for each sub-search.
                # We might set a general "Funny List" indicator for number_of_seeds in config_model.
                self.controller.set_setting('number_of_seeds', "Funny List Mode") # Placeholder
                if hasattr(self, 'number_of_seeds_var'):
                    self.number_of_seeds_var.set("Auto (List)")


            else: # Fallback for 'Funny Seeds' if it's still an option or future types
                # Fallback for other search types if any
                self.write_to_console(f"Warning: Search type '{search_type}' not fully configured for seed/count settings.\n")
                seed_value = self.starting_seed_var.get().strip()
                if not seed_value or seed_value.lower() == 'random':
                    seed_value = 'random'
                self.controller.set_setting('starting_seed', seed_value)
                current_num_seeds_setting = self.number_of_seeds_var.get()
                if current_num_seeds_setting.isdigit(): # Basic check, could expand with map like in 'Default'
                    self.controller.set_setting('number_of_seeds', int(current_num_seeds_setting))
                else:
                    self.controller.set_setting('number_of_seeds', current_num_seeds_setting)

            self.search_running = True
            self.start_time = time.time()
            self.run_button.config(text="STOP SEARCH", bg=RED) # Assuming RED is defined
            self.controller.run_search()
        else:
            self.search_running = False
            self.run_button.config(text="Let Jimbo Cook!", bg=BLUE) # Assuming BLUE is defined
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
        self.template_var.set(self.controller.get_setting('template', 'ouija_template'))

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

    def on_number_of_seeds_changed(self, event=None):
        """Handle number of seeds selection changes"""
        self.controller.set_setting('number_of_seeds', self.number_of_seeds_var.get())
    
    def open_advanced_settings_dialog(self):
        """Open the Advanced Settings dialog (thread groups, GPU batch, cutoff, fun word, search type)."""
        from .dialogs import AdvancedSettingsDialog
        result = AdvancedSettingsDialog.show_dialog(
            self.root,
            self.thread_groups_var.get(),
            self.gpu_batch_var.get(),
            self.cutoff_var.get(),
            self.fun_word_entry_var.get(),
            self.search_type_var.get(),
        )
        if result:
            self.thread_groups_var.set(result["thread_groups"])
            self.gpu_batch_var.set(result["gpu_batch"])
            self.cutoff_var.set(result["cutoff"])
            self.fun_word_entry_var.set(result["fun_word"])
            self.search_type_var.set(result["search_type"])
            # Propagate changes to controller/settings as needed
            self.controller.set_setting('thread_groups', result["thread_groups"])
            self.controller.set_setting('gpu_batch', result["gpu_batch"])
            self.controller.set_setting('cutoff', result["cutoff"])
            self.controller.set_setting('fun_word', result["fun_word"])
            self.controller.set_setting('search_type', result["search_type"])
        
        # Clear focus from the gear button to prevent visual state issues
        self.root.focus_set()

    def on_refresh_results(self):
        """Manually refresh the results table"""
        self.controller.refresh_results()
        self.set_status("Results refreshed")

    def on_delete_all_results(self):
        """Delete all results from the database after confirmation"""
        if messagebox.askyesno("Confirm Delete", 
                              "Are you sure you want to delete ALL results? This cannot be undone!",
                              icon="warning"):
            try:
                # Clear the table first for immediate visual feedback
                self.update_results_table(pd.DataFrame())
                
                # Delete from database
                if self.controller.delete_all_results():
                    self.set_status("All results deleted successfully")
                    self.write_to_console("All results deleted from database.\n")
                else:
                    self.set_status("Failed to delete results")
                    self.write_to_console("Error: Failed to delete results from database.\n")
            except Exception as e:
                self.set_status(f"Error deleting results: {str(e)}")
                self.write_to_console(f"Error deleting results: {str(e)}\n")