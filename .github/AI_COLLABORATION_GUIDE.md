# AI Collaboration Guide for Immolate/Ouija

This document helps AI assistants understand the Immolate project structure, patterns, and best practices for effective collaboration.

## 🎯 Project Overview

**Immolate** is an OpenCL-powered seed searcher for Balatro (a roguelike deckbuilder game). The project consists of:

1. **Core C Application** (`ouija.c`) - High-performance seed searching with OpenCL
2. **Python MVC GUI** (`ouija_mvc/`) - User-friendly interface for configuration and results
3. **OpenCL Templates** (`filters/`) - GPU-accelerated scoring logic for different game variants

## 🏗️ Architecture Overview

```
x:\Immolate/
├── ouija.c                    # Main C application (core engine)
├── ouija_search.cl           # OpenCL kernel entry point
├── filters/                  # OpenCL scoring templates
│   ├── ouija_template.cl         # Main scoring logic
│   └── ouija_template_anaglyph.cl # Anaglyph deck variant
├── lib/                      # Shared C/OpenCL headers
│   ├── ouija_host_result.h       # C struct definitions
│   └── ouija_result.cl           # OpenCL struct definitions (MUST MATCH C!)
├── ouija_mvc/                # Python MVC GUI application
│   ├── models/               # Data models (config, search, database)
│   ├── views/                # UI components (Tkinter-based)
│   ├── controllers/          # Business logic coordination
│   └── utils/                # Helper utilities
├── ouija_configs/            # JSON configuration files
├── ouija_database/           # SQLite databases (per config)
└── docs/                     # User documentation
```

## 🔧 Critical Technical Details

### Struct Alignment Requirements
**🚨 CRITICAL**: C and OpenCL structs MUST be byte-perfect aligned!
- **C structs**: `lib/ouija_host_result.h`
- **OpenCL structs**: `lib/ouija_result.cl`
- Any changes to one requires updating the other
- Test with different compiler settings to ensure alignment

### OpenCL Template System
The scoring logic uses template-based approach:
- `ouija_template.cl` - Standard Balatro scoring
- `ouija_template_anaglyph.cl` - Anaglyph deck with negative tag mechanics
- Templates define `score_seed()` function called by main kernel

### Boolean Arithmetic Pitfall
**⚠️ COMMON BUG**: Avoid boolean arithmetic in wants scoring!
```opencl
// ❌ WRONG - Creates fractional wants
result->ScoreWants[x] += jokerMatch && condition;

// ✅ CORRECT - Proper conditional logic
if (jokerMatch && condition) {
    result->ScoreWants[x] += 1;
}
```

### Array Initialization
**🚨 CRITICAL**: Always initialize `ScoreWants` array:
```opencl
for (int i = 0; i < MAX_DESIRES_KERNEL; i++) {
    result->ScoreWants[i] = 0;
}
```

## 🐍 Python MVC Pattern

### Models (`ouija_mvc/models/`)
- **ConfigModel**: Manages `.ouija.json` configuration files
- **SearchModel**: Handles Ouija.exe process communication
- **DatabaseModel**: SQLite database operations for results

### Views (`ouija_mvc/views/`)
- **MainWindow**: Primary UI container
- **Dialogs**: Modal dialogs for configuration editing
- Built with `tkinter` + `tksheet` for data grids

### Controllers (`ouija_mvc/controllers/`)
- **ApplicationController**: Coordinates model-view interactions
- Handles asynchronous search operations
- Manages state for "Funny List" search mode

## 🔍 Common Issues & Solutions

### Scoring Shows 0 for Positive Jokers
**Symptoms**: Positive jokers (like "Hanging Chad") show 0 wants, negatives work fine
**Causes**:
1. Uninitialized `ScoreWants` array
2. Boolean arithmetic in wants scoring
3. Double consumption of negative tag applications
4. CSV output formatting creating phantom columns

### Struct Misalignment
**Symptoms**: Garbage data, crashes, wrong results
**Solution**: Verify struct definitions match exactly between C and OpenCL

### CSV Export Issues
**Symptoms**: Extra columns, data misalignment
**Solution**: Ensure no trailing commas in CSV output formatting

## 📝 Development Workflow

### Making Changes to Scoring Logic
1. **Identify the correct template** (`ouija_template.cl` vs `ouija_template_anaglyph.cl`)
2. **Test with known configurations** (use `chadtester.ouija.json` for testing)
3. **Verify struct alignment** if modifying result structures
4. **Check CSV output format** for any new fields

### Adding New Features
1. **Start with models** - Define data structures and business logic
2. **Update controllers** - Add coordination logic
3. **Modify views** - Update UI components
4. **Test integration** - Ensure model-view-controller communication works

### Python MVC Refactoring Guidelines
- **Single Responsibility**: Each class should have one clear purpose
- **Loose Coupling**: Models shouldn't know about views directly
- **Observer Pattern**: Use callbacks for model-view communication
- **Error Handling**: Graceful degradation with user feedback

## 🎮 Game-Specific Knowledge

### Balatro Mechanics
- **Jokers**: Special cards that modify scoring and game rules
- **Negative Tags**: Allow multiple copies of jokers (Anaglyph deck)
- **Showman Joker**: Allows joker duplicates in scoring
- **The Soul**: Special spectral card that creates negative tags

### Configuration System
- **JSON-based**: `.ouija.json` files define search criteria
- **Desires Array**: Specifies wanted jokers and conditions
- **Deck Templates**: Different scoring rules for different game modes

## 🔧 Build System

### C Application
```bash
# Windows (Visual Studio)
cmake -G "Visual Studio 17 2022" -A x64 -B .\build
cmake --build .\build --config Release

# Linux
cmake -B build
cmake --build build --config Release
```

### Python Dependencies
```bash
pip install -r requirements.txt
```

### Running the Application
```bash
# C application (console)
.\Ouija.exe config_file.ouija.json

# Python GUI
python run_ouija_mvc.py
```

## 🚀 AI Collaboration Best Practices

### Before Making Changes
1. **Read relevant code sections** to understand current implementation
2. **Check for existing patterns** and follow them consistently
3. **Understand the data flow** from C engine through Python UI
4. **Identify test configurations** to validate changes

### When Investigating Bugs
1. **Start with symptoms** - What's not working?
2. **Check initialization** - Are arrays/variables properly initialized?
3. **Verify logic flow** - Trace through the scoring calculation
4. **Test with minimal cases** - Use simple configurations to isolate issues

### Code Quality Standards
- **Comments**: Explain complex game mechanics and scoring logic
- **Error Handling**: Graceful failure with informative messages
- **Performance**: Consider GPU memory bandwidth in OpenCL code
- **Maintainability**: Clear variable names, consistent formatting

---

*This guide is maintained to help AI assistants understand and work effectively with the Immolate codebase. Update as the project evolves.*
