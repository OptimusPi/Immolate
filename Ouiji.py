import tkinter as tk
from tkinter import ttk, messagebox, font
import subprocess
import threading
import json
import os
import duckdb

# Import Sun Valley theme
import sv_ttk

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

# Update the run_immolate function to use the mappings and conditional logic
def run_immolate():
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

    # --- TODO: Add logic to pass Needs/Wants/Antes ---
    # Example: command_parts.extend(["--needs", needs_list, "--wants", wants_list, "--needAnte", need_ante])

    # Join parts into the final command string
    command = " ".join(command_parts)

    print(f"Executing command: {command}")

    try:
        # Start the process
        process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, creationflags=subprocess.CREATE_NO_WINDOW)

        # Function to read stdout and parse results in real-time
        def read_output():
            output_text.delete('1.0', tk.END)  # Clear previous output
            output_text.insert(tk.END, f"Starting search with command: {command}\n---\n")
            
            while True:
                line = process.stdout.readline()
                if not line:
                    break
                
                # Check if it's a GUI result
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
            
            output_text.insert(tk.END, "--- Search Complete ---\n")
            output_text.see(tk.END)
            run_button.config(state=tk.NORMAL, text="Let Jimbo Cook!")  # Re-enable button

        # Disable button and start output thread
        run_button.config(state=tk.DISABLED, text="Cooking...")
        threading.Thread(target=read_output, daemon=True).start()

    except FileNotFoundError:
        messagebox.showerror("Error", "Ouiji.exe not found in the current directory.")
        run_button.config(state=tk.NORMAL, text="Let Jimbo Cook!")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to run Ouiji.exe: {e}")
        run_button.config(state=tk.NORMAL, text="Let Jimbo Cook!")

# Add debugging to ensure the script initializes correctly
print("Starting Immolate GUI...")

# Create the main window
root = tk.Tk()
root.title("Immolate GUI")
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
    tk.Button(search_parameters_frame, text=button_text, bg=BLUE, fg="white").pack(anchor="w", pady=2)

wants_label = tk.Label(search_parameters_frame, text="Select Wants")
wants_label.pack(anchor="w", pady=5)
add_tooltip_to_label(wants_label, "Select some wants to define the score of each seed. Some scored seed results may have none, some, or all of these jokers!")

wants_buttons = ["+ Joker", "+ Tarot", "+ Spectral", "+ Tag", "+ Voucher"]
for button_text in wants_buttons:
    tk.Button(search_parameters_frame, text=button_text, bg=BLUE, fg="white").pack(anchor="w", pady=2)

# Simplify Selected Criteria Section
selected_criteria_frame = tk.LabelFrame(settings_frame, text="Selected Criteria", padx=10, pady=10)
selected_criteria_frame.pack(fill=tk.BOTH, expand=True, side=tk.LEFT, padx=10, pady=10)
selected_criteria_frame.configure(bg="#394D53")

selected_criteria_list = tk.Listbox(selected_criteria_frame, height=15)
selected_criteria_list.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

# Update the add_joker_type function to add to the selected criteria list
def add_joker_type(joker_type):
    if joker_type:
        selected_criteria_list.insert(tk.END, joker_type)

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

# Update the "Let Jimbo Cook!" button to make it bigger and styled with fancy red and white text
run_button = tk.Button(run_settings_frame, text="Let Jimbo Cook!", command=run_immolate, bg=RED, fg="white", font=("m6x11", 18, "bold"), height=2, width=20)
run_button.pack(pady=(20,5))

# Ensure mainloop is present and reachable
root.mainloop()

print("GUI closed.")