#!/usr/bin/env python
"""
Ouija - Balatro Seed Finder (MVC Version)
Main application entry point
Author: pifreak
"""

import tkinter as tk
import sv_ttk
from .views.main_window import MainWindow
from .controllers.application_controller import ApplicationController
from .models.config_model import ConfigModel
from .models.search_model import SearchModel
from .models.database_model import DatabaseModel

def main():
    """Main entry point for the Ouija application"""
    # Initialize the root window
    root = tk.Tk()
    root.title("Ouija - Balatro Seed Finder")
    root.geometry("1200x720")
    root.configure(bg="#394D53")
    
    # Apply Sun Valley dark theme (DISABLED for tksheet compatibility)
    # sv_ttk.set_theme("dark")
    
    # Initialize models
    config_model = ConfigModel()
    search_model = SearchModel()
    database_model = DatabaseModel()
    
    # Initialize controller with models
    controller = ApplicationController(config_model, search_model, database_model)
    
    # Create the main window view and pass the controller
    main_window = MainWindow(root, controller)
    
    # Start the main event loop
    root.mainloop()

if __name__ == "__main__":
    main()