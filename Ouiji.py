# Import additional modules for process management and JSON handling
import tkinter as tk
from tkinter import ttk, messagebox, font, filedialog
import subprocess
import threading
import json
import os
import duckdb
import atexit
import signal
import sys
from datetime import datetime
import time

# Import Sun Valley theme
import sv_ttk

# Global variable to track active processes
active_processes = []

# Global variables to store selected needs and wants
needs_list = []
wants_list = []

# Joker mapping to display names and internal values
joker_mapping = {
    # Jokers - Common (J_C)
    "Joker": "Joker", 
    "Greedy Joker": "Greedy_Joker",
    "Lusty Joker": "Lusty_Joker",
    "Wrathful Joker": "Wrathful_Joker",
    "Gluttonous Joker": "Gluttonous_Joker",
    "Jolly Joker": "Jolly_Joker",
    "Zany Joker": "Zany_Joker",
    "Mad Joker": "Mad_Joker",
    "Crazy Joker": "Crazy_Joker",
    "Droll Joker": "Droll_Joker",
    "Sly Joker": "Sly_Joker",
    "Wily Joker": "Wily_Joker",
    "Clever Joker": "Clever_Joker",
    "Devious Joker": "Devious_Joker",
    "Crafty Joker": "Crafty_Joker",
    "Half Joker": "Half_Joker",
    "Credit Card": "Credit_Card",
    "Banner": "Banner",
    "Mystic Summit": "Mystic_Summit",
    "8 Ball": "_8_Ball",
    "Misprint": "Misprint",
    "Raised Fist": "Raised_Fist",
    
    # Jokers - Uncommon (J_U)
    "Joker Stencil": "Joker_Stencil",
    "Four Fingers": "Four_Fingers",
    "Mime": "Mime",
    "Ceremonial Dagger": "Ceremonial_Dagger",
    "Marble Joker": "Marble_Joker",
    "Loyalty Card": "Loyalty_Card",
    "Dusk": "Dusk",
    "Fibonacci": "Fibonacci",
    "Steel Joker": "Steel_Joker",
    "Hack": "Hack",
    "Pareidolia": "Pareidolia",
    "Space Joker": "Space_Joker",
    
    # Jokers - Rare (J_R)
    "DNA": "DNA",
    "Vampire": "Vampire",
    "Vagabond": "Vagabond",
    "Baron": "Baron",
    "Obelisk": "Obelisk",
    "Baseball Card": "Baseball_Card",
    "Ancient Joker": "Ancient_Joker",
    "Campfire": "Campfire",
    "Blueprint": "Blueprint",
    "Brainstorm": "Brainstorm",
    
    # Jokers - Legendary (J_L)
    "Canio": "Canio",
    "Triboulet": "Triboulet",
    "Yorick": "Yorick",
    "Chicot": "Chicot",
    "Perkeo": "Perkeo",
    
    # Spectral cards
    "Familiar": "Familiar",
    "Ankh": "Ankh",
    "Ectoplasm": "Ectoplasm",
    "The Soul": "The_Soul",
    
    # Tags
    "Negative Tag": "Negative_Tag",
    "Orbital Tag": "Orbital_Tag",
    
    # Vouchers
    "Observatory": "Observatory",
    "Telescope": "Telescope",
    "Magic Trick": "Magic_Trick",
}

# Map of all available jokers, tarots, etc
available_items = {
    "Jokers": ["Showman", "Perkeo", "Blueprint", "Ankh", "DNA", "Ectoplasm", "Brainstorm", "The Soul", 
               "Canio", "Oops All 6s", "Invisible Joker", "Trading Card", "Space Joker"],
    "Tarots": ["The Fool", "The Magician", "The High Priestess", "The Empress", "The Emperor",
               "The Hierophant", "The Lovers", "The Chariot", "Justice", "The Hermit"],
    "Spectrals": ["Spectral Wolf", "Spectral Burn", "Spectral Ice", "Spectral Bolt",
                  "Spectral Venom", "Spectral Force", "Spectral Radiance"],
    "Tags": ["Orbital Tag", "Negative Tag"],
    "Vouchers": ["Observatory", "Telescope", "Magic Trick", "Mystic Summit"]
}

# Function to terminate all active processes on exit
def cleanup_processes():
    for process in active_processes:
        try:
            if process.poll() is None:  # Process is still running
                print(f"Terminating process with PID {process.pid}")
                # Force kill the process
                if os.name == 'nt':  # Windows
                    subprocess.call(['taskkill', '/F', '/T', '/PID', str(process.pid)])
                else:  # Unix/Linux/Mac
                    os.kill(process.pid, signal.SIGKILL)
        except Exception as e:
            print(f"Error terminating process: {e}")

# Register the cleanup function to run on exit
atexit.register(cleanup_processes)

# Handle signals for more graceful termination
def signal_handler(sig, frame):
    print("Received termination signal, cleaning up...")
    cleanup_processes()
    sys.exit(0)

# Register signal handlers
signal.signal(signal.SIGINT, signal_handler)
if os.name == 'nt':  # Windows
    signal.signal(signal.SIGBREAK, signal_handler)
else:  # Unix/Linux/Mac
    signal.signal(signal.SIGTERM, signal_handler)

# Custom Tooltip implementation
class Tooltip:
    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self.tooltip_window = None
        self.widget.bind("<Enter>", self.show_tooltip)
        self.widget.bind("<Leave>", self.hide_tooltip)

    def show_tooltip(self, event=None):
        if self.tooltip_window or not self.text:
            return
        x, y, _, _ = self.widget.bbox("insert")
        x += self.widget.winfo_rootx() + 25
        y += self.widget.winfo_rooty() + 20
        self.tooltip_window = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")
        label = tk.Label(tw, text=self.text, justify="left",
                         background="#333333", foreground="white", relief="solid", borderwidth=1,
                         font=("m6x11", 12))
        label.pack(ipadx=1)

    def hide_tooltip(self, event=None):
        if self.tooltip_window:
            self.tooltip_window.destroy()
            self.tooltip_window = None

def initialize_database(filter_path):
    db_path = filter_path.replace('.cl', '.duckdb')
    conn = duckdb.connect(db_path)
    return conn

def create_table(conn, joker_columns):
    columns = ["Seed TEXT"] + [f"{joker} INTEGER" for joker in joker_columns] + ["Total_Jokers INTEGER", "Generic_Score INTEGER"]
    columns_definition = ", ".join(columns)
    conn.execute(f"CREATE TABLE IF NOT EXISTS results ({columns_definition});")

def insert_result(conn, result):
    placeholders = ", ".join(["?"] * len(result))
    conn.execute(f"INSERT INTO results VALUES ({placeholders});", result)

def query_results(conn):
    return conn.execute("SELECT * FROM results;").fetchall()

# Mappings for dropdown values to command-line arguments
thread_group_map = {
    "Single": "1",
    "Default (16)": "16",
    "32": "32",
    "64": "64",
    "128": "128",
    "256": "256"
}

seed_count_map = {
    "Single (1)": "1",
    "Default (All Seeds)": None, # Use None to indicate omitting the argument
    "1K": "1000",
    "100K": "100000",
    "1M": "1000000",
    "100M": "100000000",
    "1B": "1000000000"
}

def run_ouiji_cmd():
    # If the button is in "STOP SEARCH" mode, terminate the process
    if run_button.cget("text") == "STOP SEARCH":
        cleanup_processes()  # Use our existing cleanup function
        run_button.config(text="Let Jimbo Cook!", bg=RED)
        output_text.insert(tk.END, "\n--- Search Stopped ---\n")
        output_text.see(tk.END)
        return

    # Check if we have criteria without having exported
    if (needs_list or wants_list) and not config_name_entry.get().strip():
        # Ask user if they want to export the configuration first
        if messagebox.askyesno("Export Configuration", 
                              "You have selected criteria but haven't named/exported your configuration.\n\n" +
                              "Would you like to export it before running?"):
            export_configuration()
    
    starting_seed = starting_seed_entry.get()
    number_of_seeds_label = number_of_seeds_var.get()
    thread_groups_label = default_thread_group.get()

    # Get numerical values from mappings
    number_of_seeds_value = seed_count_map.get(number_of_seeds_label) # Get value, could be None
    thread_groups_value = thread_group_map.get(thread_groups_label, "16") # Default to 16 if somehow not found

    # Construct the base command using a list
    command_parts = [".\\Ouiji.exe"]

    # Add starting seed
    command_parts.extend(["-s", starting_seed])

    # Add number of seeds argument ONLY if a specific value (not None) is selected
    if number_of_seeds_value is not None:
        command_parts.extend(["-n", number_of_seeds_value])

    # Add thread groups argument
    command_parts.extend(["-g", thread_groups_value])
    
    # Add GUI mode flag
    command_parts.append("--gui")
    
    # If we have criteria, generate a temporary config file to use
    if needs_list or wants_list:
        config_name = config_name_entry.get().strip()
        if not config_name:
            config_name = f"temp_config_{int(time.time())}"
            
        # Create configuration object
        config = {
            "name": config_name,
            "description": f"Temporary configuration created on {datetime.now().strftime('%Y-%m-%d')}",
            "author": "Ouiji GUI User",
            "filter_config": {
                "numNeeds": len(needs_list),
                "numWants": len(wants_list),
                "Needs": needs_list,
                "Wants": wants_list,
                "maxSearchAnte": 8  # Default to searching all antes
            }
        }
        
        # Make sure the ouiji_configs directory exists
        os.makedirs("ouiji_configs", exist_ok=True)
        
        # Create a temporary configuration file
        temp_config_path = os.path.join("ouiji_configs", f"{config_name}.ouiji.json")
        
        with open(temp_config_path, 'w') as file:
            json.dump(config, file, indent=4)
        
        # Add config flag to command
        command_parts.extend(["--config", temp_config_path])
    
    # Join parts into the final command string
    command = " ".join(command_parts)

    print(f"{command}")

    try:
        # Start the process
        process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, creationflags=subprocess.CREATE_NO_WINDOW)
        
        # Add to our list of active processes
        active_processes.append(process)

        # Function to read stdout and parse results in real-time
        def read_output():
            output_text.delete('1.0', tk.END)  # Clear previous output
            output_text.insert(tk.END, "--- Search Starting ---\n")
            output_text.insert(tk.END, f"Command: {command}\n\n")
            
            try:
                while True:
                    # Check if process is still running
                    if process.poll() is not None:
                        break
                    
                    line = process.stdout.readline()
                    if not line:
                        break
                    
                    # Process GUI result format
                    if line.startswith("GUI_RESULT|"):
                        parts = line.strip().split("|")
                        if len(parts) >= 4:
                            seed = parts[1]
                            score = parts[2]
                            wants_mask = parts[3]
                            formatted_result = f"SEED: {seed} | SCORE: {score} | WANTS: {wants_mask}\n"
                            output_text.insert(tk.END, formatted_result)
                    else:
                        # Regular output lines
                        output_text.insert(tk.END, line)
                    
                    output_text.see(tk.END)  # Auto-scroll to the latest output
                
                # Process any stderr after stdout is done
                for line in process.stderr:
                    output_text.insert(tk.END, f"ERROR: {line}\n")
                    output_text.see(tk.END)
                
                # Remove process from active list
                if process in active_processes:
                    active_processes.remove(process)
                
                output_text.insert(tk.END, "--- Search Complete ---\n")
                output_text.see(tk.END)
                
                # Reset the button back to "Let Jimbo Cook!"
                run_button.config(text="Let Jimbo Cook!", bg=RED)
            except Exception as e:
                output_text.insert(tk.END, f"Error reading process output: {e}\n")
                output_text.see(tk.END)
                # Reset button on error
                run_button.config(text="Let Jimbo Cook!", bg=RED)

        # Change button to "STOP SEARCH" mode instead of disabling
        run_button.config(text="STOP SEARCH", bg="#FF0000")  # Bright red for stop
        
        # Start reading output in a background thread
        threading.Thread(target=read_output, daemon=True).start()

    except FileNotFoundError:
        messagebox.showerror("Error", "Ouiji.exe not found in the current directory.")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to run Ouiji.exe: {e}")

# Add dialog for selecting a joker or other item
class ItemSelectorDialog(tk.Toplevel):
    def __init__(self, parent, title, category="Jokers", is_need=True):
        super().__init__(parent)
        self.title(title)
        self.geometry("400x500")
        self.resizable(False, False)
        
        self.category = category
        self.is_need = is_need
        self.selected_item = None
        self.selected_ante = 4  # Default ante value
        
        # Main frame
        self.main_frame = tk.Frame(self)
        self.main_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Category selector
        self.category_frame = tk.LabelFrame(self.main_frame, text="Category")
        self.category_frame.pack(fill="x", padx=5, pady=5)
        
        self.category_var = tk.StringVar(value=category)
        
        for cat in available_items.keys():
            rb = tk.Radiobutton(self.category_frame, text=cat, variable=self.category_var, 
                                value=cat, command=self.update_items_list)
            rb.pack(side="left", padx=5)
        
        # Items listbox
        self.items_frame = tk.LabelFrame(self.main_frame, text="Items")
        self.items_frame.pack(fill="both", expand=True, padx=5, pady=5)
        
        self.items_listbox = tk.Listbox(self.items_frame)
        self.items_listbox.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Ante selection for needs
        if is_need:
            self.ante_frame = tk.LabelFrame(self.main_frame, text="Required by Ante")
            self.ante_frame.pack(fill="x", padx=5, pady=5)
            
            self.ante_var = tk.IntVar(value=4)
            for ante in range(1, 9):
                rb = tk.Radiobutton(self.ante_frame, text=f"Ante {ante}", variable=self.ante_var, value=ante)
                rb.pack(side="left")
        
        # Edition frame for jokers (simplified)
        self.edition_frame = tk.LabelFrame(self.main_frame, text="Edition")
        self.edition_frame.pack(fill="x", padx=5, pady=5)
        
        self.edition_var = tk.StringVar(value="No_Edition")
        editions = ["No_Edition", "Foil", "Holographic", "Polychrome", "Negative"]
        for edition in editions:
            rb = tk.Radiobutton(self.edition_frame, text=edition, variable=self.edition_var, value=edition)
            rb.pack(side="left")
        
        # Buttons
        self.button_frame = tk.Frame(self.main_frame)
        self.button_frame.pack(fill="x", padx=5, pady=10)
        
        self.select_button = tk.Button(self.button_frame, text="Select", command=self.on_select)
        self.select_button.pack(side="left", padx=5)
        
        self.cancel_button = tk.Button(self.button_frame, text="Cancel", command=self.destroy)
        self.cancel_button.pack(side="right", padx=5)
        
        # Initialize items list
        self.update_items_list()
    
    def update_items_list(self):
        self.items_listbox.delete(0, tk.END)
        category = self.category_var.get()
        for item in available_items.get(category, []):
            self.items_listbox.insert(tk.END, item)
    
    def on_select(self):
        if not self.items_listbox.curselection():
            messagebox.showerror("Error", "Please select an item")
            return
        
        selected_index = self.items_listbox.curselection()[0]
        category = self.category_var.get()
        selected_item = available_items[category][selected_index]
        
        # Convert display name to internal value for selected item
        internal_value = joker_mapping.get(selected_item, selected_item.replace(" ", "_"))
        
        result = {
            "type": category[:-1],  # Remove 's' from end: Jokers -> Joker
            "value": internal_value
        }
        
        # Add edition info for jokers
        if category == "Jokers":
            edition = self.edition_var.get()
            if edition != "No_Edition":
                result["joker"] = {
                    "joker": internal_value,
                    "edition": edition
                }
        
        # Add ante requirement for needs
        if self.is_need:
            result["desireByAnte"] = self.ante_var.get()
        else:
            # For wants, default to searching all antes
            result["desireByAnte"] = 8
            
        if self.is_need:
            needs_list.append(result)
        else:
            wants_list.append(result)
            
        # Update the criteria list display
        display_text = f"{'NEED' if self.is_need else 'WANT'}: {selected_item}"
        if self.is_need:
            display_text += f" by Ante {result['desireByAnte']}"
        if "joker" in result and result["joker"]["edition"] != "No_Edition":
            display_text += f" ({result['joker']['edition']})"
            
        selected_criteria_list.insert(tk.END, display_text)
        
        self.destroy()

# Add buttons to trigger the item selector dialogs
def add_need_item():
    dialog = ItemSelectorDialog(root, "Select Need Item", "Jokers", True)
    dialog.wait_window()

def add_want_item():
    dialog = ItemSelectorDialog(root, "Select Want Item", "Jokers", False)
    dialog.wait_window()

# Clear all selected criteria
def clear_criteria():
    selected_criteria_list.delete(0, tk.END)
    needs_list.clear()
    wants_list.clear()

# Enhanced export function to create proper JSON structure
def export_configuration():
    config_name = config_name_entry.get().strip()
    if not config_name:
        messagebox.showerror("Error", "Please enter a configuration name before exporting.")
        return
        
    if not needs_list and not wants_list:
        messagebox.showerror("Error", "Please add at least one Need or Want before exporting.")
        return
    
    # Create configuration object matching perkeo_finder.ouiji.json format
    config = {
        "name": config_name,
        "description": f"Filter configuration created by Ouiji GUI on {datetime.now().strftime('%Y-%m-%d')}",
        "author": "Ouiji GUI User",
        "filter_config": {
            "numNeeds": len(needs_list),
            "numWants": len(wants_list),
            "Needs": needs_list,
            "Wants": wants_list,
            "maxSearchAnte": 8  # Default to searching all antes
        }
    }
    
    # Suggest filename based on config name
    suggested_filename = config_name.lower().replace(" ", "_") + ".ouiji.json"
    
    # Make sure the ouiji_configs directory exists
    os.makedirs("ouiji_configs", exist_ok=True)
    
    file_path = filedialog.asksaveasfilename(
        initialdir="ouiji_configs",
        initialfile=suggested_filename,
        defaultextension=".json", 
        filetypes=[("Ouiji JSON files", "*.ouiji.json"), ("All files", "*.*")]
    )
    
    if file_path:
        with open(file_path, 'w') as file:
            json.dump(config, file, indent=4)
        messagebox.showinfo("Success", f"Configuration exported to {file_path}")
        
        # Also generate a --config parameter example
        config_param = f"--config \"{os.path.basename(file_path)}\""
        output_text.insert(tk.END, f"\n--- Configuration Export ---\n")
        output_text.insert(tk.END, f"To use this configuration, run:\n{config_param}\n")
        output_text.see(tk.END)

# Add debugging to ensure the script initializes correctly
print("Starting Ouiji GUI...")

# Create the main window
root = tk.Tk()
root.title("Ouiji - Balatro Seed Finder by pifreak")
# Set default window size to 720p
root.geometry("1200x720")

# Set the background color of the main window to #394D53 (grey)
root.configure(bg="#394D53")

# Apply Sun Valley theme
sv_ttk.set_theme("dark")  # Options: "light" or "dark"

# Correctly load the m6x11 font
custom_font = font.nametofont("TkDefaultFont")
custom_font.configure(family="m6x11", size=16)
root.option_add("*Font", custom_font)

# Define custom colors
BLUE = "#008DFB"
RED = "#F94C3E"

# Organize layout into sections
settings_frame = tk.Frame(root)
settings_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
settings_frame.configure(bg="#394D53")

# Update labels to act as tooltips on hover
def add_tooltip_to_label(label, tooltip_text):
    def show_tooltip(event):
        x, y, _, _ = label.bbox("insert")
        x += label.winfo_rootx() + 25
        y += label.winfo_rooty() + 20
        tooltip_window = tk.Toplevel(label)
        tooltip_window.wm_overrideredirect(True)
        tooltip_window.wm_geometry(f"+{x}+{y}")
        tooltip_label = tk.Label(tooltip_window, text=tooltip_text, justify="left",
                                 background="#333333", foreground="white", relief="solid", borderwidth=1,
                                 font=("m6x11", 12))
        tooltip_label.pack(ipadx=1)
        label.tooltip_window = tooltip_window

    def hide_tooltip(event):
        if hasattr(label, 'tooltip_window') and label.tooltip_window:
            label.tooltip_window.destroy()
            label.tooltip_window = None

    label.bind("<Enter>", show_tooltip)
    label.bind("<Leave>", hide_tooltip)

search_parameters_frame = tk.LabelFrame(settings_frame, text="Search Parameters", padx=10, pady=10)
search_parameters_frame.pack(fill=tk.X, expand=True, side=tk.LEFT, padx=10, pady=10)
search_parameters_frame.configure(bg="#394D53")

# Add buttons for Needs and Wants into Search Parameters section
needs_label = tk.Label(search_parameters_frame, text="Select Needs")
needs_label.pack(anchor="w", pady=5)
add_tooltip_to_label(needs_label, "Selecting too many Needs may return no results. If no results display, wait longer or try to be less Needy!")

needs_buttons = ["+ Joker", "+ Tarot", "+ Spectral", "+ Tag", "+ Voucher"]
for button_text in needs_buttons:
    tk.Button(search_parameters_frame, text=button_text, bg=BLUE, fg="white", command=add_need_item).pack(anchor="w", pady=2)

wants_label = tk.Label(search_parameters_frame, text="Select Wants")
wants_label.pack(anchor="w", pady=5)
add_tooltip_to_label(wants_label, "Select some wants to define the score of each seed. Some scored seed results may have none, some, or all of these jokers!")

wants_buttons = ["+ Joker", "+ Tarot", "+ Spectral", "+ Tag", "+ Voucher"]
for button_text in wants_buttons:
    tk.Button(search_parameters_frame, text=button_text, bg=BLUE, fg="white", command=add_want_item).pack(anchor="w", pady=2)

# Simplify Selected Criteria Section
selected_criteria_frame = tk.LabelFrame(settings_frame, text="Selected Criteria", padx=10, pady=10)
selected_criteria_frame.pack(fill=tk.BOTH, expand=True, side=tk.LEFT, padx=10, pady=10)
selected_criteria_frame.configure(bg="#394D53")

selected_criteria_list = tk.Listbox(selected_criteria_frame, height=15)
selected_criteria_list.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

# Add a Text widget to display output
output_text = tk.Text(root, wrap=tk.WORD, height=15)
output_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)

# Update the "Start Search" button to red
add_tooltip_to_label(wants_label, "Select some wants to define the score of each seed. Some scored seed results may have none, some, or all of these jokers!")
# Run Settings Section
run_settings_frame = tk.LabelFrame(settings_frame, text="Run Settings", padx=10, pady=10)
run_settings_frame.pack(fill=tk.BOTH, expand=False, side=tk.LEFT, padx=10, pady=10)
run_settings_frame.config(width=int(root.winfo_screenwidth() * 0.2))
run_settings_frame.configure(bg="#394D53")

thread_group_label = tk.Label(run_settings_frame, text="GPU Thread Groups:")
thread_group_label.pack(pady=5)
add_tooltip_to_label(thread_group_label, "Select the number of GPU thread groups to use. Use 'Single' for analyzing one seed. Optimal value differs per system. Experimenting/Benchmarking Recommended!")

default_thread_group = tk.StringVar(value="Default (16)")
thread_group_dropdown = ttk.Combobox(run_settings_frame, textvariable=default_thread_group, state="readonly")
thread_group_dropdown['values'] = ["Single", "Default (16)", "32", "64", "128", "256"]
thread_group_dropdown.pack(pady=(5, 25))  # Add more space below the dropdown

# Add Starting Seed and Number of Seeds to Search settings
starting_seed_label = tk.Label(run_settings_frame, text="Starting Seed")
starting_seed_label.pack(pady=(5, 5))

# Limit the Starting Seed input to 8 characters
starting_seed_entry = tk.Entry(run_settings_frame, validate="key")
starting_seed_entry.insert(0, "random")  # Default value changed from "random" to random
starting_seed_entry.pack(pady=(5, 5))

# Add validation to enforce 8-character limit and seed dictionary
seed_dictionary = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

def validate_seed_input(new_value):
    return len(new_value) <= 8 and all(char in seed_dictionary for char in new_value)

vcmd = (root.register(validate_seed_input), '%P')
starting_seed_entry.configure(validatecommand=vcmd)

number_of_seeds_label = tk.Label(run_settings_frame, text="Search Size")
number_of_seeds_label.pack(pady=5)

number_of_seeds_var = tk.StringVar(value="Default (All Seeds)")
number_of_seeds_dropdown = ttk.Combobox(run_settings_frame, textvariable=number_of_seeds_var, state="readonly")
number_of_seeds_dropdown['values'] = ["Single (1)", "Default (All Seeds)", "1K", "100K", "1M", "100M", "1B"]
number_of_seeds_dropdown.pack(pady=5)

# Add Configuration Name field
config_name_label = tk.Label(run_settings_frame, text="Configuration Name")
config_name_label.pack(pady=5)

config_name_entry = tk.Entry(run_settings_frame)
config_name_entry.pack(pady=5)

# Add Export Configuration Button
export_button = tk.Button(run_settings_frame, text="Export Configuration", command=export_configuration, bg=BLUE, fg="white")
export_button.pack(pady=5)

# Add Clear Criteria Button
clear_button = tk.Button(run_settings_frame, text="Clear Criteria", command=clear_criteria, bg=RED, fg="white")
clear_button.pack(pady=5)

# Update the "Let Jimbo Cook!" button to make it bigger and styled with fancy red and white text
run_button = tk.Button(run_settings_frame, text="Let Jimbo Cook!", command=run_ouiji_cmd, bg=RED, fg="white", font=("m6x11", 18, "bold"), height=2, width=20)
run_button.pack(pady=(20,5))

# Bind window close event to cleanup function
def on_closing():
    print("Window closing, cleaning up processes...")
    cleanup_processes()
    root.destroy()

root.protocol("WM_DELETE_WINDOW", on_closing)

# Ensure mainloop is present and reachable
root.mainloop()

print("GUI closed.")