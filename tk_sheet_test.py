import tkinter as tk
import tksheet

root = tk.Tk()
sheet = tksheet.Sheet(root,
                      data=[[1, 2], [3, 4]],
                      headers=["A", "B"])
sheet.pack(expand=True, fill="both")

# Set a built-in theme
sheet.set_theme("light blue")  # Try "dark", "light green", etc.

# Or highlight specific cells
sheet.highlight_cells(row=0, column=0, bg="yellow", fg="red")

print(tksheet.__version__)

root.mainloop()