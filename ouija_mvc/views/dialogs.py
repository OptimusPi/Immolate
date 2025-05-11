"""
Dialog Windows for Ouija Seed Finder
"""
import tkinter as tk
from tkinter import ttk
from ..utils.ui_utils import BLUE, RED, GREEN, BACKGROUND
from ..utils.game_data import AVAILABLE_ITEMS, JOKER_EDITIONS, get_internal_name


class ItemSelectorDialog(tk.Toplevel):
    """Dialog window for selecting an item (joker, tarot, etc.)"""
    
    def __init__(self, parent, title, category="Jokers", is_need=True):
        """Initialize the dialog window
        
        Args:
            parent: Parent window
            title: Dialog title
            category: Item category to choose from ("Jokers", "Tarots", etc.)
            is_need: Whether this item is a Need (required) or Want
        """
        super().__init__(parent)
        self.title(title)
        self.geometry("700x750")  # Initial size
        self.resizable(True, True)  # Allow resizing
        self.configure(bg=BACKGROUND)
        
        self.category = category
        self.is_need = is_need
        self.selected_item = None
        self.selected_ante = 0
        self.selected_edition = "No_Edition"
        self.result = None  # Will store the final result on selection
        
        # Main container frame
        self.main_frame = tk.Frame(self, bg=BACKGROUND)
        self.main_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Title showing the current category
        category_label = tk.Label(self.main_frame, text=f"Selecting: {category}", 
                                 font=("m6x11", 16), bg=BACKGROUND, fg="white")
        category_label.pack(fill="x", padx=5, pady=5)
        
        # Search field
        self.search_frame = tk.Frame(self.main_frame, bg=BACKGROUND)
        self.search_frame.pack(fill="x", padx=5, pady=5)
        
        tk.Label(self.search_frame, text="Search:", bg=BACKGROUND, fg="white").pack(side="left", padx=5)
        self.search_var = tk.StringVar()
        self.search_var.trace("w", self.filter_items)
        self.search_entry = tk.Entry(self.search_frame, textvariable=self.search_var)
        self.search_entry.pack(side="left", fill="x", expand=True, padx=5)
        
        # Items listbox with scrollbar
        self.items_frame = tk.LabelFrame(self.main_frame, text="Items", bg=BACKGROUND, fg="white")
        self.items_frame.pack(fill="x", expand=True, padx=5, pady=5)
        
        self.listbox_frame = tk.Frame(self.items_frame, bg=BACKGROUND)
        self.listbox_frame.pack(fill="both", expand=True, padx=5, pady=5)
        
        self.item_scrollbar = tk.Scrollbar(self.listbox_frame)
        self.item_scrollbar.pack(side="right", fill="y")
        
        # This is the main scrollable component - only the items list scrolls
        self.items_listbox = tk.Listbox(self.listbox_frame, yscrollcommand=self.item_scrollbar.set, 
                                      selectmode="single", height=15, exportselection=False,
                                      bg="#2E3B42", fg="white")
        self.items_listbox.pack(side="left", fill="both", expand=True)
        self.item_scrollbar.config(command=self.items_listbox.yview)
        
        # Ante selection for needs - horizontal radio buttons with better visibility
        if is_need:
            self.ante_frame = tk.LabelFrame(self.main_frame, text="Required by Ante", 
                                          bg=BACKGROUND, fg="white")
            self.ante_frame.pack(side=tk.LEFT, fill="y", padx=5, pady=5)
            
            self.ante_var = tk.IntVar(value=1)  # Default to Ante 1 for needs
            ante_container = tk.Frame(self.ante_frame, bg=BACKGROUND)
            ante_container.pack(side=tk.LEFT, fill="y", padx=5, pady=5)
            
            # Create four rows of ante buttons with clearer spacing
            for ante in range(1, 9):
                rb = ttk.Radiobutton(ante_container, text=f"Ante {ante}", 
                                    variable=self.ante_var, value=ante)
                rb.grid(row=(ante-1)%4, column=(ante-1)//4, padx=5, pady=2, sticky="w")
            nah = ttk.Radiobutton(ante_container, text=f"Not required, just Want.", 
                                 variable=self.ante_var, value=0)
            nah.grid(row=5, column=0, columnspan=2, padx=5, pady=2, sticky="w")
        
        # Edition frame for jokers (better organized)
        if category == "Jokers":  # Only show edition options for Jokers
            self.edition_frame = tk.LabelFrame(self.main_frame, text="Edition", 
                                             bg=BACKGROUND, fg="white")
            self.edition_frame.pack(side=tk.LEFT, fill="y", padx=5, pady=5)
            
            self.edition_var = tk.StringVar(value="No_Edition")
            
            edition_container = tk.Frame(self.edition_frame, bg=BACKGROUND)
            edition_container.pack(fill="x", padx=5, pady=5)
            
            for i, edition in enumerate(JOKER_EDITIONS):
                rb = ttk.Radiobutton(edition_container, text=edition, 
                                    variable=self.edition_var, value=edition)
                rb.grid(row=i, column=0, padx=5, pady=2, sticky="w")
        
        # Buttons
        self.button_frame = tk.Frame(self.main_frame, bg=BACKGROUND)
        self.button_frame.pack(side=tk.BOTTOM, fill="x", padx=5, pady=5)
        
        self.select_button = tk.Button(self.button_frame, text="Select", command=self.on_select,
                                     width=15, height=2, bg=BLUE, fg="white")
        self.select_button.pack(side="right", padx=20, pady=5)
        
        self.cancel_button = tk.Button(self.button_frame, text="Cancel", command=self.destroy,
                                     width=15, height=2, bg=RED, fg="white")
        self.cancel_button.pack(side="left", padx=20, pady=5)
        
        # Initialize items list with the pre-selected category
        self.update_items_list()
        
        # Make dialog modal
        self.transient(parent)
        self.grab_set()
        self.protocol("WM_DELETE_WINDOW", self.destroy)
        
        # Set focus to search entry for immediate typing
        self.search_entry.focus_set()
    
    def filter_items(self, *args):
        """Filter the items list based on the search term"""
        self.update_items_list()
    
    def update_items_list(self):
        """Update the items listbox with filtered items"""
        self.items_listbox.delete(0, tk.END)
        search_term = self.search_var.get().lower()
        
        for item in AVAILABLE_ITEMS.get(self.category, []):
            if search_term == "" or search_term in item.lower():
                self.items_listbox.insert(tk.END, item)
    
    def on_select(self):
        """Handle item selection"""
        if not self.items_listbox.curselection():
            return False
        
        selected_index = self.items_listbox.curselection()[0]
        selected_item = self.items_listbox.get(selected_index)
        
        # Convert display name to internal value
        internal_value = get_internal_name(selected_item)
        
        # Create result object
        result = {
            "value": internal_value,
            "desireByAnte": self.ante_var.get() if hasattr(self, 'ante_var') else 0
        }
        
        # Add edition info for jokers
        if self.category == "Jokers" and hasattr(self, 'edition_var'):
            edition = self.edition_var.get()
            if edition != "No_Edition":
                result["jokeredition"] = edition
        
        # Store the result and close the dialog
        self.result = result
        self.destroy()
        return True
    
    @staticmethod
    def show_dialog(parent, title, category="Jokers", is_need=True):
        """Show the dialog and return the result
        
        Args:
            parent: Parent window
            title: Dialog title
            category: Item category to choose from
            is_need: Whether this item is a Need
            
        Returns:
            Dict with the selected item details or None if cancelled
        """
        dialog = ItemSelectorDialog(parent, title, category, is_need)
        parent.wait_window(dialog)
        return getattr(dialog, 'result', None)