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
    # Jokers - Common
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
    "Chaos the Clown": "Chaos_the_Clown",
    "Scary Face": "Scary_Face",
    "Abstract Joker": "Abstract_Joker",
    "Delayed Gratification": "Delayed_Gratification",
    "Gros Michel": "Gros_Michel",
    "Even Steven": "Even_Steven",
    "Odd Todd": "Odd_Todd",
    "Scholar": "Scholar",
    "Business Card": "Business_Card",
    "Supernova": "Supernova",
    "Ride the Bus": "Ride_the_Bus",
    "Egg": "Egg",
    "Runner": "Runner",
    "Ice Cream": "Ice_Cream",
    "Splash": "Splash",
    "Blue Joker": "Blue_Joker",
    "Faceless Joker": "Faceless_Joker",
    "Green Joker": "Green_Joker",
    "Superposition": "Superposition",
    "To Do List": "To_Do_List",
    "Cavendish": "Cavendish",
    "Red Card": "Red_Card",
    "Square Joker": "Square_Joker",
    "Riff raff": "Riff_raff",
    "Photograph": "Photograph",
    "Reserved Parking": "Reserved_Parking",
    "Mail In Rebate": "Mail_In_Rebate",
    "Hallucination": "Hallucination",
    "Fortune Teller": "Fortune_Teller",
    "Juggler": "Juggler",
    "Drunkard": "Drunkard",
    "Golden Joker": "Golden_Joker",
    "Popcorn": "Popcorn",
    "Walkie Talkie": "Walkie_Talkie",
    "Smiley Face": "Smiley_Face",
    "Golden Ticket": "Golden_Ticket",
    "Swashbuckler": "Swashbuckler",
    "Hanging Chad": "Hanging_Chad",
    "Shoot the Moon": "Shoot_the_Moon",
    
    # Jokers - Uncommon
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
    "Burglar": "Burglar",
    "Blackboard": "Blackboard",
    "Sixth Sense": "Sixth_Sense",
    "Constellation": "Constellation",
    "Hiker": "Hiker",
    "Card Sharp": "Card_Sharp",
    "Madness": "Madness",
    "Seance": "Seance",
    "Shortcut": "Shortcut",
    "Hologram": "Hologram",
    "Cloud 9": "Cloud_9",
    "Rocket": "Rocket",
    "Midas Mask": "Midas_Mask",
    "Luchador": "Luchador",
    "Gift Card": "Gift_Card",
    "Turtle Bean": "Turtle_Bean",
    "Erosion": "Erosion",
    "To the Moon": "To_the_Moon",
    "Stone Joker": "Stone_Joker",
    "Lucky Cat": "Lucky_Cat",
    "Bull": "Bull",
    "Diet Cola": "Diet_Cola",
    "Trading Card": "Trading_Card",
    "Flash Card": "Flash_Card",
    "Spare Trousers": "Spare_Trousers",
    "Ramen": "Ramen",
    "Seltzer": "Seltzer",
    "Castle": "Castle",
    "Mr Bones": "Mr_Bones",
    "Acrobat": "Acrobat",
    "Sock and Buskin": "Sock_and_Buskin",
    "Troubadour": "Troubadour",
    "Certificate": "Certificate",
    "Smeared Joker": "Smeared_Joker",
    "Throwback": "Throwback",
    "Rough Gem": "Rough_Gem",
    "Bloodstone": "Bloodstone",
    "Arrowhead": "Arrowhead",
    "Onyx Agate": "Onyx_Agate",
    "Glass Joker": "Glass_Joker",
    "Showman": "Showman",
    "Flower Pot": "Flower_Pot",
    "Merry Andy": "Merry_Andy",
    "Oops All 6s": "Oops_All_6s",
    "The Idol": "The_Idol",
    "Seeing Double": "Seeing_Double",
    "Matador": "Matador",
    "Stuntman": "Stuntman",
    "Satellite": "Satellite",
    "Cartomancer": "Cartomancer",
    "Astronomer": "Astronomer",
    "Bootstraps": "Bootstraps",
    
    # Jokers - Rare
    "DNA": "DNA",
    "Vampire": "Vampire",
    "Vagabond": "Vagabond",
    "Baron": "Baron",
    "Obelisk": "Obelisk",
    "Baseball Card": "Baseball_Card",
    "Ancient Joker": "Ancient_Joker",
    "Campfire": "Campfire",
    "Blueprint": "Blueprint",
    "Wee Joker": "Wee_Joker",
    "Hit the Road": "Hit_the_Road",
    "The Duo": "The_Duo",
    "The Trio": "The_Trio",
    "The Family": "The_Family",
    "The Order": "The_Order",
    "The Tribe": "The_Tribe",
    "Invisible Joker": "Invisible_Joker",
    "Brainstorm": "Brainstorm",
    "Drivers License": "Drivers_License",
    "Burnt Joker": "Burnt_Joker",
    
    # Jokers - Legendary
    "Canio": "Canio",
    "Triboulet": "Triboulet",
    "Yorick": "Yorick",
    "Chicot": "Chicot",
    "Perkeo": "Perkeo",
    
    # Tarots
    "The Fool": "The_Fool",
    "The Magician": "The_Magician",
    "The High Priestess": "The_High_Priestess",
    "The Empress": "The_Empress",
    "The Emperor": "The_Emperor",
    "The Hierophant": "The_Hierophant",
    "The Lovers": "The_Lovers",
    "The Chariot": "The_Chariot",
    "Justice": "Justice",
    "The Hermit": "The_Hermit",
    "The Wheel of Fortune": "The_Wheel_of_Fortune",
    "Strength": "Strength",
    "The Hanged Man": "The_Hanged_Man",
    "Death": "Death",
    "Temperance": "Temperance",
    "The Devil": "The_Devil",
    "The Tower": "The_Tower",
    "The Star": "The_Star",
    "The Moon": "The_Moon",
    "The Sun": "The_Sun",
    "Judgement": "Judgement",
    "The World": "The_World",
    
    # Spectrals
    "Familiar": "Familiar",
    "Grim": "Grim",
    "Incantation": "Incantation",
    "Talisman": "Talisman",
    "Aura": "Aura",
    "Wraith": "Wraith",
    "Sigil": "Sigil",
    "Ouija": "Ouija",
    "Ectoplasm": "Ectoplasm",
    "Immolate": "Immolate",
    "Ankh": "Ankh",
    "Deja Vu": "Deja_Vu",
    "Hex": "Hex",
    "Trance": "Trance",
    "Medium": "Medium",
    "Cryptid": "Cryptid",
    "The Soul": "The_Soul",
    "Black Hole": "Black_Hole",
    
    # Tags
    "Uncommon Tag": "Uncommon_Tag",
    "Rare Tag": "Rare_Tag",
    "Negative Tag": "Negative_Tag",
    "Foil Tag": "Foil_Tag",
    "Holographic Tag": "Holographic_Tag",
    "Polychrome Tag": "Polychrome_Tag",
    "Investment Tag": "Investment_Tag",
    "Voucher Tag": "Voucher_Tag",
    "Boss Tag": "Boss_Tag",
    "Standard Tag": "Standard_Tag",
    "Charm Tag": "Charm_Tag",
    "Meteor Tag": "Meteor_Tag",
    "Buffoon Tag": "Buffoon_Tag",
    "Handy Tag": "Handy_Tag",
    "Garbage Tag": "Garbage_Tag",
    "Ethereal Tag": "Ethereal_Tag",
    "Coupon Tag": "Coupon_Tag",
    "Double Tag": "Double_Tag",
    "Juggle Tag": "Juggle_Tag",
    "D6 Tag": "D6_Tag",
    "Top up Tag": "Top_up_Tag",
    "Speed Tag": "Speed_Tag",
    "Orbital Tag": "Orbital_Tag",
    "Economy Tag": "Economy_Tag",
    
    # Vouchers
    "Overstock": "Overstock",
    "Overstock Plus": "Overstock_Plus",
    "Clearance Sale": "Clearance_Sale",
    "Liquidation": "Liquidation",
    "Hone": "Hone",
    "Glow Up": "Glow_Up",
    "Reroll Surplus": "Reroll_Surplus",
    "Reroll Glut": "Reroll_Glut",
    "Crystal Ball": "Crystal_Ball",
    "Omen Globe": "Omen_Globe",
    "Telescope": "Telescope",
    "Observatory": "Observatory",
    "Grabber": "Grabber",
    "Nacho Tong": "Nacho_Tong",
    "Wasteful": "Wasteful",
    "Recyclomancy": "Recyclomancy",
    "Tarot Merchant": "Tarot_Merchant",
    "Tarot Tycoon": "Tarot_Tycoon",
    "Planet Merchant": "Planet_Merchant",
    "Planet Tycoon": "Planet_Tycoon",
    "Seed Money": "Seed_Money",
    "Money Tree": "Money_Tree",
    "Blank": "Blank",
    "Antimatter": "Antimatter",
    "Magic Trick": "Magic_Trick",
    "Illusion": "Illusion",
    "Hieroglyph": "Hieroglyph",
    "Petroglyph": "Petroglyph",
    "Directors Cut": "Directors_Cut",
    "Retcon": "Retcon",
    "Paint Brush": "Paint_Brush",
    "Palette": "Palette",
    
    # Decks
    "Red Deck": "Red_Deck",
    "Blue Deck": "Blue_Deck",
    "Yellow Deck": "Yellow_Deck",
    "Green Deck": "Green_Deck",
    "Black Deck": "Black_Deck",
    "Magic Deck": "Magic_Deck",
    "Nebula Deck": "Nebula_Deck",
    "Ghost Deck": "Ghost_Deck",
    "Abandoned Deck": "Abandoned_Deck",
    "Checkered Deck": "Checkered_Deck",
    "Zodiac Deck": "Zodiac_Deck",
    "Painted Deck": "Painted_Deck",
    "Anaglyph Deck": "Anaglyph_Deck", 
    "Plasma Deck": "Plasma_Deck",
    "Erratic Deck": "Erratic_Deck",
    
    # Stakes
    "White Stake": "White_Stake",
    "Red Stake": "Red_Stake",
    "Green Stake": "Green_Stake",
    "Black Stake": "Black_Stake",
    "Blue Stake": "Blue_Stake",
    "Purple Stake": "Purple_Stake",
    "Orange Stake": "Orange_Stake",
    "Gold Stake": "Gold_Stake"
}

# Map of all available jokers, tarots, etc
available_items = {
    "Jokers": [
        # Common Jokers
        "Joker", "Greedy Joker", "Lusty Joker", "Wrathful Joker", "Gluttonous Joker",
        "Jolly Joker", "Zany Joker", "Mad Joker", "Crazy Joker", "Droll Joker",
        "Sly Joker", "Wily Joker", "Clever Joker", "Devious Joker", "Crafty Joker",
        "Half Joker", "Credit Card", "Banner", "Mystic Summit", "8 Ball",
        "Misprint", "Raised Fist", "Chaos the Clown", "Scary Face", "Abstract Joker",
        "Delayed Gratification", "Gros Michel", "Even Steven", "Odd Todd", "Scholar",
        "Business Card", "Supernova", "Ride the Bus", "Egg", "Runner",
        "Ice Cream", "Splash", "Blue Joker", "Faceless Joker", "Green Joker",
        "Superposition", "To Do List", "Cavendish", "Red Card", "Square Joker",
        "Riff raff", "Photograph", "Reserved Parking", "Mail In Rebate", "Hallucination",
        "Fortune Teller", "Juggler", "Drunkard", "Golden Joker", "Popcorn",
        "Walkie Talkie", "Smiley Face", "Golden Ticket", "Swashbuckler", "Hanging Chad",
        "Shoot the Moon",
        # Uncommon Jokers
        "Joker Stencil", "Four Fingers", "Mime", "Ceremonial Dagger", "Marble Joker",
        "Loyalty Card", "Dusk", "Fibonacci", "Steel Joker", "Hack",
        "Pareidolia", "Space Joker", "Burglar", "Blackboard", "Sixth Sense",
        "Constellation", "Hiker", "Card Sharp", "Madness", "Seance",
        "Shortcut", "Hologram", "Cloud 9", "Rocket", "Midas Mask",
        "Luchador", "Gift Card", "Turtle Bean", "Erosion", "To the Moon",
        "Stone Joker", "Lucky Cat", "Bull", "Diet Cola", "Trading Card",
        "Flash Card", "Spare Trousers", "Ramen", "Seltzer", "Castle",
        "Mr Bones", "Acrobat", "Sock and Buskin", "Troubadour", "Certificate",
        "Smeared Joker", "Throwback", "Rough Gem", "Bloodstone", "Arrowhead",
        "Onyx Agate", "Glass Joker", "Showman", "Flower Pot", "Merry Andy",
        "Oops All 6s", "The Idol", "Seeing Double", "Matador", "Stuntman",
        "Satellite", "Cartomancer", "Astronomer", "Bootstraps",
        # Rare Jokers
        "DNA", "Vampire", "Vagabond", "Baron", "Obelisk",
        "Baseball Card", "Ancient Joker", "Campfire", "Blueprint", "Wee Joker",
        "Hit the Road", "The Duo", "The Trio", "The Family", "The Order",
        "The Tribe", "Invisible Joker", "Brainstorm", "Drivers License", "Burnt Joker",
        # Legendary Jokers
        "Canio", "Triboulet", "Yorick", "Chicot", "Perkeo"
    ],
    "Tarots": [
        "The Fool", "The Magician", "The High Priestess", "The Empress", "The Emperor",
        "The Hierophant", "The Lovers", "The Chariot", "Justice", "The Hermit",
        "The Wheel of Fortune", "Strength", "The Hanged Man", "Death", "Temperance",
        "The Devil", "The Tower", "The Star", "The Moon", "The Sun",
        "Judgement", "The World"
    ],
    "Spectrals": [
        "Familiar", "Grim", "Incantation", "Talisman", "Aura",
        "Wraith", "Sigil", "Ouija", "Ectoplasm", "Immolate",
        "Ankh", "Deja Vu", "Hex", "Trance", "Medium",
        "Cryptid", "The Soul", "Black Hole"
    ],
    "Tags": [
        "Uncommon Tag", "Rare Tag", "Negative Tag", "Foil Tag", "Holographic Tag",
        "Polychrome Tag", "Investment Tag", "Voucher Tag", "Boss Tag", "Standard Tag",
        "Charm Tag", "Meteor Tag", "Buffoon Tag", "Handy Tag", "Garbage Tag",
        "Ethereal Tag", "Coupon Tag", "Double Tag", "Juggle Tag", "D6 Tag",
        "Top up Tag", "Speed Tag", "Orbital Tag", "Economy Tag"
    ],
    "Vouchers": [
        "Overstock", "Overstock Plus", "Clearance Sale", "Liquidation", "Hone",
        "Glow Up", "Reroll Surplus", "Reroll Glut", "Crystal Ball", "Omen Globe",
        "Telescope", "Observatory", "Grabber", "Nacho Tong", "Wasteful",
        "Recyclomancy", "Tarot Merchant", "Tarot Tycoon", "Planet Merchant", "Planet Tycoon",
        "Seed Money", "Money Tree", "Blank", "Antimatter", "Magic Trick",
        "Illusion", "Hieroglyph", "Petroglyph", "Directors Cut", "Retcon",
        "Paint Brush", "Palette"
    ],
    "Decks": [
        "Red Deck", "Blue Deck", "Yellow Deck", "Green Deck", "Black Deck",
        "Magic Deck", "Nebula Deck", "Ghost Deck", "Abandoned Deck", "Checkered Deck",
        "Zodiac Deck", "Painted Deck", "Anaglyph Deck", "Plasma Deck", "Erratic Deck"
    ],
    "Stakes": [
        "White Stake", "Red Stake", "Green Stake", "Black Stake",
        "Blue Stake", "Purple Stake", "Orange Stake", "Gold Stake"
    ]
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
                "maxSearchAnte": 8,  # Default to searching all antes
                "deck": joker_mapping.get(deck_var.get(), deck_var.get()),  # Get internal value of selected deck
                "stake": joker_mapping.get(stake_var.get(), stake_var.get())  # Get internal value of selected stake
            }
        }
        
        # Make sure the ouiji_configs directory exists
        os.makedirs("ouiji_configs", exist_ok=True)
        
        # Create a temporary configuration file
        temp_config_path = f"{config_name}"
        
        with open(temp_config_path, "w") as file:
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
            try:
                while True:
                    # Check if process is still running
                    if process.poll() is not None:
                        break
                    
                    line = process.stdout.readline()
                    if not line:
                        break
                    
                    # Process GUI result format
                    if line.startswith("|"):
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
        self.geometry("700x750")  # Initial size
        self.resizable(True, True)  # Allow resizing
        
        self.category = category
        self.is_need = is_need
        self.selected_item = None
        self.selected_ante = 0
        
        # Main container frame
        self.main_frame = tk.Frame(self)
        self.main_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Title showing the current category
        category_label = tk.Label(self.main_frame, text=f"Selecting: {category}", font=("m6x11", 16, "bold"))
        category_label.pack(fill="x", padx=5, pady=5)
        
        # Search field
        self.search_frame = tk.Frame(self.main_frame)
        self.search_frame.pack(fill="x", padx=5, pady=5)
        
        tk.Label(self.search_frame, text="Search:").pack(side="left", padx=5)
        self.search_var = tk.StringVar()
        self.search_var.trace("w", self.filter_items)
        self.search_entry = tk.Entry(self.search_frame, textvariable=self.search_var)
        self.search_entry.pack(side="left", fill="x", expand=True, padx=5)
        
        # Items listbox with scrollbar
        self.items_frame = tk.LabelFrame(self.main_frame, text="Items")
        self.items_frame.pack(fill="x", expand=True, padx=5, pady=5)
        
        self.listbox_frame = tk.Frame(self.items_frame)
        self.listbox_frame.pack(fill="both", expand=True, padx=5, pady=5)
        
        self.item_scrollbar = tk.Scrollbar(self.listbox_frame)
        self.item_scrollbar.pack(side="right", fill="y")
        
        # This is the main scrollable component now - only the items list scrolls
        self.items_listbox = tk.Listbox(self.listbox_frame, yscrollcommand=self.item_scrollbar.set, 
                                        selectmode="single", height=15, exportselection=False)
        self.items_listbox.pack(side="left", fill="both", expand=True)
        self.item_scrollbar.config(command=self.items_listbox.yview)
        
        # Ante selection for needs - horizontal radio buttons with better visibility
        if is_need:
            self.ante_frame = tk.LabelFrame(self.main_frame, text="Required by Ante")
            self.ante_frame.pack(side=tk.LEFT, fill="y", padx=5, pady=5)
            
            self.ante_var = tk.IntVar(value=0)
            ante_container = tk.Frame(self.ante_frame)
            ante_container.pack(side=tk.LEFT, fill="y", padx=5, pady=5)
            
            # Create four rows of ante buttons with clearer spacing
            for ante in range(1, 9):
                rb = ttk.Radiobutton(ante_container, text=f"Ante {ante}", variable=self.ante_var, value=ante)
                rb.grid(row=(ante-1)%4, column=(ante-1)//4, padx=5, pady=2, sticky="w")
            nah = ttk.Radiobutton(ante_container, text=f"Not required, just Want.", variable=self.ante_var, value=0)
            nah.grid(row=5, column=0, columnspan=2, padx=5, pady=2, sticky="w")
        
        # Edition frame for jokers (better organized)
        if category == "Jokers":  # Only show edition options for Jokers
            self.edition_frame = tk.LabelFrame(self.main_frame, text="Edition")
            self.edition_frame.pack(side=tk.LEFT, fill="y", padx=5, pady=5)  # Increased padding
            
            self.edition_var = tk.StringVar(value="No_Edition")
            editions = ["No_Edition", "Foil", "Holographic", "Polychrome", "Negative"]
            
            edition_container = tk.Frame(self.edition_frame)
            edition_container.pack(fill="x", padx=5, pady=5)  # Increased padding
            
            for i, edition in enumerate(editions):
                rb = ttk.Radiobutton(edition_container, text=edition, variable=self.edition_var, value=edition)
                rb.grid(row=i, column=0, padx=5, pady=2, sticky="w")
        
        # Buttons
        self.button_frame = tk.Frame(self.main_frame)
        self.button_frame.pack(side=tk.BOTTOM, fill="x", padx=5, pady=5)  # Increased padding
        
        self.select_button = tk.Button(self.button_frame, text="Select", command=self.on_select,
                                      width=15, height=2)  # Larger buttons
        self.select_button.pack(side="right", padx=20, pady=5)
        
        self.cancel_button = tk.Button(self.button_frame, text="Cancel", command=self.destroy,
                                      width=15, height=2)  # Larger buttons
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
        self.update_items_list()
    
    def update_items_list(self):
        self.items_listbox.delete(0, tk.END)
        search_term = self.search_var.get().lower()
        
        for item in available_items.get(self.category, []):
            if search_term == "" or search_term in item.lower():
                self.items_listbox.insert(tk.END, item)
    
    def on_select(self):
        if not self.items_listbox.curselection():
            messagebox.showerror("Error", "Please select an item")
            return
        
        selected_index = self.items_listbox.curselection()[0]
        selected_item = self.items_listbox.get(selected_index)
        
        # Convert display name to internal value for selected item
        internal_value = joker_mapping.get(selected_item, selected_item.replace(" ", "_"))
        
        result = {
            "type": category_to_item_type(self.category),  # Convert category name to type
            "value": internal_value
        }
        
        # Add edition info for jokers
        if self.category == "Jokers":
            edition = self.edition_var.get()
            result["joker"] = {
                "joker": internal_value,
                "edition": edition
            }
        
        # Add ante requirement for needs
        result["desireByAnte"] = self.ante_var.get()
            
        # If this was originally a "Need" but the ante is set to 0 (nah option),
        # treat it as a "Want" instead
        if self.is_need and result["desireByAnte"] == 0:
            # Convert to a want
            wants_list.append(result)
            display_text = f"WANT: {selected_item}"
        elif self.is_need:
            # Regular need
            needs_list.append(result)
            display_text = f"NEED: {selected_item} by Ante {result['desireByAnte']}"
        else:
            # Regular want
            wants_list.append(result)
            display_text = f"WANT: {selected_item}"
            
        # Add edition info to display text if applicable
        if self.category == "Jokers" and "joker" in result and result["joker"]["edition"] != "No_Edition":
            display_text += f" ({result['joker']['edition']})"
            
        selected_criteria_list.insert(tk.END, display_text)
        
        self.destroy()

# Helper function to convert category name to item type
def category_to_item_type(category):
    print("Converting category to item type: %s\n", category)
    # Remove the trailing 's' from the category name to get the item type
    # Special case for some plurals
    if category == "Jokers":
        return "Desire_Joker"
    elif category == "Tarots":
        return "Desire_Tarot"
    elif category == "Spectrals":
        return "Desire_Spectral"
    elif category == "Tags":
        return "Desire_Tag"
    elif category == "Vouchers":
        return "Desire_Voucher"
    else:
        return f"Desire_{category[:-1]}"
    

# Add buttons to trigger the item selector dialogs for different categories
def add_need_joker():
    dialog = ItemSelectorDialog(root, "Select Need Joker", "Jokers", True)
    dialog.wait_window()

def add_need_tarot():
    dialog = ItemSelectorDialog(root, "Select Need Tarot", "Tarots", True)
    dialog.wait_window()

def add_need_spectral():
    dialog = ItemSelectorDialog(root, "Select Need Spectral", "Spectrals", True)
    dialog.wait_window()

def add_need_tag():
    dialog = ItemSelectorDialog(root, "Select Need Tag", "Tags", True)
    dialog.wait_window()

def add_need_voucher():
    dialog = ItemSelectorDialog(root, "Select Need Voucher", "Vouchers", True)
    dialog.wait_window()

def add_want_joker():
    dialog = ItemSelectorDialog(root, "Select Want Joker", "Jokers", False)
    dialog.wait_window()

def add_want_tarot():
    dialog = ItemSelectorDialog(root, "Select Want Tarot", "Tarots", False)
    dialog.wait_window()

def add_want_spectral():
    dialog = ItemSelectorDialog(root, "Select Want Spectral", "Spectrals", False)
    dialog.wait_window()

def add_want_tag():
    dialog = ItemSelectorDialog(root, "Select Want Tag", "Tags", False)
    dialog.wait_window()

def add_want_voucher():
    dialog = ItemSelectorDialog(root, "Select Want Voucher", "Vouchers", False)
    dialog.wait_window()

# Clear all selected criteria
def clear_all_criteria():
    selected_criteria_list.delete(0, tk.END)
    needs_list.clear()
    wants_list.clear()

# Clear only the single currently selected criteria
def clear_criteria():
    selected_indices = selected_criteria_list.curselection()
    if selected_indices:
        for index in reversed(selected_indices):
            selected_criteria_list.delete(index)
            if index < len(needs_list):
                needs_list.pop(index)
            else:
                wants_list.pop(index - len(needs_list))

# Make randomized configuration for fun!
def randomize_all_criteria():
    # Clear existing criteria before randomizing
    clear_all_criteria()
    import random
    # Randomly select between 2-10 items
    num_items = random.randint(1, 10)
    
    # Categories to randomly pick from, with weights favoring jokers
    categories = ["Jokers", "Jokers", "Jokers", "Tarots", "Spectrals", "Tags", "Vouchers"]
    
    # Ensure at least one need
    need_count = random.randint(1, min(3, num_items))
    want_count = num_items - need_count
    
    # Add random needs
    for i in range(need_count):
        # Pick a random category
        category = random.choice(categories)
        # Pick a random item from that category
        selected_item = random.choice(available_items[category])
        internal_value = joker_mapping.get(selected_item, selected_item.replace(" ", "_"))
        
        result = {
            "type": category_to_item_type(category),
            "value": internal_value,
            "desireByAnte": random.randint(1, 8)  # Random ante requirement
        }
        
        # Add random edition for jokers with 30% chance
        if category == "Jokers" and random.random() < 0.3:
            editions = ["Foil", "Holographic", "Polychrome", "Negative"]
            edition = random.choice(editions)
            result["joker"] = {
                "joker": internal_value,
                "edition": edition
            }
            needs_list.append(result)
            selected_criteria_list.insert(tk.END, f"NEED: {selected_item} by Ante {result['desireByAnte']} ({edition})")
        else:
            needs_list.append(result)
            selected_criteria_list.insert(tk.END, f"NEED: {selected_item} by Ante {result['desireByAnte']}")
    
    # Add random wants
    for i in range(want_count):
        category = random.choice(categories)
        selected_item = random.choice(available_items[category])
        internal_value = joker_mapping.get(selected_item, selected_item.replace(" ", "_"))
        
        result = {
            "type": category_to_item_type(category),
            "value": internal_value,
            "desireByAnte": 8  # Default to searching all antes
        }
        
        # Add random edition for jokers with 30% chance
        if category == "Jokers" and random.random() < 0.3:
            editions = ["Foil", "Holographic", "Polychrome", "Negative"]
            edition = random.choice(editions)
            result["joker"] = {
                "joker": internal_value,
                "edition": edition
            }
            wants_list.append(result)
            selected_criteria_list.insert(tk.END, f"WANT: {selected_item} ({edition})")
        else:
            wants_list.append(result)
            selected_criteria_list.insert(tk.END, f"WANT: {selected_item}")
    
    # Also randomly select a deck and stake
    deck_var.set(random.choice(available_items["Decks"]))
    stake_var.set(random.choice(available_items["Stakes"]))
    
    # Set a random name for the configuration
    adjectives = ["Spicy", "Lucky", "Glorious", "Mysterious", "Powerful", "Chaotic", "Epic", "Golden", "Legendary", "Magical"]
    nouns = ["Fortune", "Destiny", "Victory", "Adventure", "Jackpot", "Treasure", "Poker", "Champion", "Joker", "Triumph"]
    config_name_entry.delete(0, tk.END)
    config_name_entry.insert(0, f"{random.choice(adjectives)}{random.choice(nouns)}")

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
            "maxSearchAnte": 8,  # Default to searching all antes
            "deck": joker_mapping.get(deck_var.get(), deck_var.get()),  # Get internal value of selected deck
            "stake": joker_mapping.get(stake_var.get(), stake_var.get())  # Get internal value of selected stake
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
        output_text.insert(tk.END, f"Using {deck_var.get()} with {stake_var.get()}\n")
        output_text.see(tk.END)

# Function to load a saved configuration
def load_configuration():
    # Make sure the ouiji_configs directory exists
    os.makedirs("ouiji_configs", exist_ok=True)
    
    file_path = filedialog.askopenfilename(
        initialdir="ouiji_configs",
        title="Load Configuration",
        filetypes=[("Ouiji JSON files", "*.ouiji.json"), ("All files", "*.*")]
    )
    
    if not file_path:
        return
        
    try:
        with open(file_path, 'r') as file:
            config = json.load(file)
            
        # Clear current configuration
        clear_criteria()
        
        # Set configuration name
        config_name = config.get("name", os.path.basename(file_path).replace('.ouiji.json', ''))
        config_name_entry.delete(0, tk.END)
        config_name_entry.insert(0, config_name)
        
        # Load needs
        needs_list.clear()
        for need in config.get("filter_config", {}).get("Needs", []):
            needs_list.append(need)
            
            # Display in the criteria list
            display_text = f"NEED: {need['value'].replace('_', ' ')}"
            if "desireByAnte" in need:
                display_text += f" by Ante {need['desireByAnte']}"
            if "joker" in need and "edition" in need["joker"] and need["joker"]["edition"] != "No_Edition":
                display_text += f" ({need['joker']['edition']})"
                
            selected_criteria_list.insert(tk.END, display_text)
        
        # Load wants
        wants_list.clear()
        for want in config.get("filter_config", {}).get("Wants", []):
            wants_list.append(want)
            
            # Display in the criteria list
            display_text = f"WANT: {want['value'].replace('_', ' ')}"
            if "desireByAnte" in want:
                display_text += f" by Ante {want['desireByAnte']}"
            if "joker" in want and "edition" in want["joker"] and want["joker"]["edition"] != "No_Edition":
                display_text += f" ({want['joker']['edition']})"
                
            selected_criteria_list.insert(tk.END, display_text)
        
        # Load deck if specified in config
        filter_config = config.get("filter_config", {})
        if "deck" in filter_config:
            deck_name = filter_config["deck"].replace('_', ' ')
            # Try to find the matching deck in the available items
            # First try a direct match
            if deck_name in available_items["Decks"]:
                deck_var.set(deck_name)
            else:
                # Try to find the name from the internal value
                for display_name, internal_name in joker_mapping.items():
                    if internal_name == filter_config["deck"] and display_name in available_items["Decks"]:
                        deck_var.set(display_name)
                        break
        
        # Load stake if specified in config
        if "stake" in filter_config:
            stake_name = filter_config["stake"].replace('_', ' ')
            # Try to find the matching stake in the available items
            # First try a direct match
            if stake_name in available_items["Stakes"]:
                stake_var.set(stake_name)
            else:
                # Try to find the name from the internal value
                for display_name, internal_name in joker_mapping.items():
                    if internal_name == filter_config["stake"] and display_name in available_items["Stakes"]:
                        stake_var.set(display_name)
                        break
        
        messagebox.showinfo("Success", f"Configuration loaded from {os.path.basename(file_path)}")
        
    except Exception as e:
        messagebox.showerror("Error", f"Failed to load configuration: {str(e)}")

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
GREEN = "#4CAF50"

# Organize layout into sections
settings_frame = tk.Frame(root)
settings_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
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

# Create left side container for search and deck parameters
left_parameters_frame = tk.Frame(settings_frame)
left_parameters_frame.pack(fill=tk.Y, side=tk.LEFT, padx=5, pady=5)
left_parameters_frame.configure(bg="#394D53")

custom_config_frame = tk.LabelFrame(left_parameters_frame, text="Custom Configuration", padx=10, pady=10)
custom_config_frame.pack(fill=tk.X, expand=True, side=tk.TOP, padx=10, pady=10)
custom_config_frame.configure(bg="#394D53")


# Add Configuration Name field
config_name_label = tk.Label(custom_config_frame, text="Configuration Name")
config_name_label.pack(anchor="w",pady=5)

config_name_entry = tk.Entry(custom_config_frame)
config_name_entry.pack(pady=5)

# Add Export Configuration Button
export_button = tk.Button(custom_config_frame, text="Save Configuration", command=export_configuration, bg=BLUE, fg="white")
export_button.pack(pady=5)

# Add Load Configuration Button
load_button = tk.Button(custom_config_frame, text="Load Configuration", command=load_configuration, bg=BLUE, fg="white")
load_button.pack(pady=5)

# Create a new Deck Parameters section below Search Parameters
deck_parameters_frame = tk.LabelFrame(left_parameters_frame, text="Deck Parameters", padx=10, pady=10)
deck_parameters_frame.pack(fill=tk.X, expand=False, side=tk.TOP, padx=10, pady=10)
deck_parameters_frame.configure(bg="#394D53")

# Add Deck dropdown to the new deck parameters section
deck_label = tk.Label(deck_parameters_frame, text="Deck")
deck_label.pack(pady=5)
add_tooltip_to_label(deck_label, "Select the deck to use for the search")

deck_var = tk.StringVar(value="Red Deck")
deck_dropdown = ttk.Combobox(deck_parameters_frame, textvariable=deck_var, state="readonly")
deck_dropdown['values'] = available_items["Decks"]
deck_dropdown.pack(pady=5, fill=tk.X)

# Add Stake dropdown to the new deck parameters section
stake_label = tk.Label(deck_parameters_frame, text="Stake")
stake_label.pack(pady=5)
add_tooltip_to_label(stake_label, "Select the stake to use for the search")

stake_var = tk.StringVar(value="Black Stake")
stake_dropdown = ttk.Combobox(deck_parameters_frame, textvariable=stake_var, state="readonly")
stake_dropdown['values'] = available_items["Stakes"]
stake_dropdown.pack(pady=5, fill=tk.X)

# Simplify Selected Criteria Section
selected_criteria_frame = tk.LabelFrame(settings_frame, text="Selected Criteria", padx=10, pady=10)
selected_criteria_frame.configure(bg="#394D53")
selected_criteria_frame.pack(fill=tk.BOTH, expand=True, side=tk.LEFT, padx=10, pady=10)

# Updated buttons with specific commands for each type
add_criteria_buttons_frame = tk.Frame(selected_criteria_frame)
tk.Button(add_criteria_buttons_frame, text="+ Joker", bg=BLUE, fg="white", command=add_need_joker).pack(anchor="w", side=tk.LEFT, padx=5)
tk.Button(add_criteria_buttons_frame, text="+ Tarot", bg=BLUE, fg="white", command=add_need_tarot).pack(side=tk.LEFT, padx=5)
tk.Button(add_criteria_buttons_frame, text="+ Spectral", bg=BLUE, fg="white", command=add_need_spectral).pack(side=tk.LEFT, padx=5)
tk.Button(add_criteria_buttons_frame, text="+ Tag", bg=BLUE, fg="white", command=add_need_tag).pack(side=tk.LEFT, padx=5)
tk.Button(add_criteria_buttons_frame, text="+ Voucher", bg=BLUE, fg="white", command=add_need_voucher).pack(side=tk.LEFT, padx=5)
add_criteria_buttons_frame.configure(bg="#394D53")
add_criteria_buttons_frame.pack(fill=tk.X, side=tk.TOP, padx=5, pady=5)

show_criteria = tk.Frame(selected_criteria_frame)
selected_criteria_list = tk.Listbox(show_criteria, height=15)
selected_criteria_list.pack(fill=tk.X, expand=True, side=tk.BOTTOM, padx=5, pady=5)
show_criteria.configure(bg="#394D53")
show_criteria.pack(fill=tk.X, side=tk.TOP, padx=5)

special_criteria_frame = tk.Frame(selected_criteria_frame)
tk.Button(special_criteria_frame, text="Randomize! 🎲", command=randomize_all_criteria, bg=GREEN, fg="white").pack(side=tk.LEFT, pady=3)
tk.Button(special_criteria_frame, text="Clear All", command=clear_all_criteria, bg=RED, fg="white").pack(side=tk.RIGHT, pady=3)
tk.Button(special_criteria_frame, text="Remove Selected Item", command=clear_criteria, bg=RED, fg="white").pack(side=tk.RIGHT, padx=3)
special_criteria_frame.configure(bg="#394D53")
special_criteria_frame.pack(fill=tk.X, side=tk.BOTTOM, padx=10)

# Run Settings Section
run_settings_frame = tk.LabelFrame(settings_frame, text="Run Settings", padx=10, pady=10)
run_settings_frame.pack(fill=tk.BOTH, expand=False, side=tk.LEFT, padx=10, pady=10)
run_settings_frame.config(width=int(root.winfo_screenwidth() * 0.2))
run_settings_frame.configure(bg="#394D53")

thread_group_label = tk.Label(run_settings_frame, text="GPU Thread Groups:")
thread_group_label.pack(anchor="w", pady=5)
add_tooltip_to_label(thread_group_label, "Select the number of GPU thread groups to use. Use 'Single' for analyzing one seed. Optimal value differs per system. Experimenting/Benchmarking Recommended!")

default_thread_group = tk.StringVar(value="Default (16)")
thread_group_dropdown = ttk.Combobox(run_settings_frame, textvariable=default_thread_group, state="readonly")
thread_group_dropdown['values'] = ["Single", "Default (16)", "32", "64", "128", "256"]
thread_group_dropdown.pack(pady=(5, 10))  # Add more space below the dropdown

# Add Starting Seed and Number of Seeds to Search settings
starting_seed_label = tk.Label(run_settings_frame, text="Starting Seed")
starting_seed_label.pack(anchor="w", pady=5)

# Limit the Starting Seed input to 8 characters
starting_seed_entry = tk.Entry(run_settings_frame, validate="key")
starting_seed_entry.insert(0, "random")  # Default value changed from "random" to random
starting_seed_entry.pack(anchor="w",pady=(5, 5))

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
run_button = tk.Button(run_settings_frame, text="Let Jimbo Cook!", command=run_ouiji_cmd, bg=BLUE, fg="white", font=("m6x11", 18, "bold"), height=2, width=20)
run_button.pack(pady=(20,5))

# Add a Text widget to display output
output_text = tk.Text(root, wrap=tk.WORD, height=15)
output_text.pack(fill=tk.BOTH, side=tk.BOTTOM, expand=True, padx=5, pady=5)
output_text.configure(bg="#394D53", fg="white", font=("m6x11", 12), insertbackground='white')

# Bind window close event to cleanup function
def on_closing():
    print("Window closing, cleaning up processes...")
    cleanup_processes()
    root.destroy()

root.protocol("WM_DELETE_WINDOW", on_closing)

# Ensure mainloop is present and reachable
root.mainloop()

print("Ouiji GUI is closing...")
print("pifreak loves you!")