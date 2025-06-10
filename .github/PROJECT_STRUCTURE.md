# Project Structure Reference

Detailed breakdown of the Immolate project file organization and dependencies.

## 📁 Root Directory
```
x:\Immolate/
├── 📄 ouija.c                    # Main C application entry point
├── 📄 ouija_search.cl           # OpenCL kernel entry point
├── 📄 CMakeLists.txt            # Build configuration
├── 📄 README.md                 # User documentation
├── 📄 requirements.txt          # Python dependencies
├── 📄 run_ouija_mvc.py          # Python GUI launcher
├── 📄 LICENSE                   # MIT License
├── 📄 .gitignore               # Git ignore rules
└── 📄 ouija_user.conf          # User preferences
```

## 🧠 Core Engine (`/`)
### Main Executables
- **`ouija.c`** - Core C application, handles OpenCL setup and execution
- **`Ouija.exe`** - Compiled executable (various build variants available)
- **`ouija_search.cl`** - OpenCL kernel entry point, dispatches to templates

### Configuration
- **`ouija_user.conf`** - User preferences (OpenCL device selection, etc.)

## 🔧 OpenCL Templates (`/filters/`)
```
filters/
├── 📄 ouija_template.cl         # Main Balatro scoring template
└── 📄 ouija_template_anaglyph.cl # Anaglyph deck variant template
```

**Purpose**: Define scoring logic for different game modes
- Templates implement `score_seed()` function
- Called by main OpenCL kernel for each seed
- Must handle joker scoring, wants tracking, and special mechanics

## 📚 Shared Libraries (`/lib/`)
```
lib/
├── 📄 ouija_host_result.h       # C struct definitions
├── 📄 ouija_result.cl          # OpenCL struct definitions (MUST MATCH!)
├── 📄 joker_defines.h          # Joker ID constants
└── 📄 desires.h                # Desires structure definitions
```

**⚠️ CRITICAL**: C and OpenCL structs must be byte-perfect aligned!

## 🐍 Python MVC Application (`/ouija_mvc/`)
```
ouija_mvc/
├── 📄 app.py                   # Application entry point
├── 📄 __init__.py             # Package initialization
├── 📁 models/                 # Data models
│   ├── 📄 config_model.py         # Configuration management
│   ├── 📄 search_model.py         # Search process coordination
│   ├── 📄 database_model.py       # SQLite database operations
│   └── 📄 __init__.py
├── 📁 views/                  # UI components
│   ├── 📄 main_window.py          # Primary application window
│   ├── 📄 dialogs.py              # Modal dialogs
│   └── 📄 __init__.py
├── 📁 controllers/            # Business logic coordination
│   ├── 📄 application_controller.py # Main controller
│   └── 📄 __init__.py
└── 📁 utils/                  # Helper utilities
    ├── 📄 game_data.py            # Balatro game data definitions
    ├── 📄 ui_utils.py             # UI helper functions
    └── 📄 __init__.py
```

### Model Responsibilities
- **ConfigModel**: Load/save `.ouija.json` files, validation
- **SearchModel**: Manage Ouija.exe process, handle results
- **DatabaseModel**: SQLite operations, results storage

### View Responsibilities  
- **MainWindow**: Primary UI container, results display
- **Dialogs**: Configuration editing, criteria management

### Controller Responsibilities
- **ApplicationController**: Coordinate model-view interactions
- Handle asynchronous operations
- Manage application state

## ⚙️ Configuration System (`/ouija_configs/`)
```
ouija_configs/
├── 📄 config_name.ouija.json   # Main configuration file
├── 📄 config_name.wants        # Human-readable desires (optional)
└── 📄 chadtester.ouija.json   # Test configuration
```

**Configuration Structure**:
```json
{
    "ConfigName": "Test Configuration",
    "Description": "Testing positive joker scoring",
    "SearchMode": "FirstFound",
    "Desires": [
        {
            "JokerID": 123,
            "Count": 1,
            "NegativeTag": false
        }
    ]
}
```

## 🗄️ Database System (`/ouija_database/`)
```
ouija_database/
└── 📄 config_name.db           # SQLite database per configuration
```

**Tables**:
- `results` - Search results with seed data
- `searches` - Search run metadata
- Schema auto-created by DatabaseModel

## 📊 Data Export (`/ouija_csv_exports/`)
```
ouija_csv_exports/
└── 📄 config_name_YYYYMMDD_HHMMSS.csv # Timestamped exports
```

## 📖 Documentation (`/docs/`)
```
docs/
├── 📄 getting_started.md       # User guide
├── 📄 troubleshooting.md      # Common issues
└── 📄 advanced_usage.md       # Power user features
```

## 🔨 Build System (`/build/`)
```
build/                         # CMake build output
├── 📁 Release/               # Release build artifacts
├── 📁 Debug/                 # Debug build artifacts
└── 📄 CMakeCache.txt         # Build configuration cache
```

## 🧪 Testing & Profiling
```
├── 📁 ouija_benchmark/        # Performance benchmarks
├── 📁 profiling/             # Profiling results and tools
├── 📄 Ouija-profile.exe      # Profiling build
├── 📄 Ouija-optimized.exe    # Optimized build
└── 📄 check_layout.c         # Struct alignment verification
```

## 🔗 Dependencies

### External Libraries (C/C++)
- **OpenCL** - GPU computation
- **DuckDB** - Database operations (if used)
- **CMake** - Build system

### Python Dependencies
```
duckdb>=0.8.1          # Database operations
pandas>=2.0.0          # Data manipulation
tksheet>=6.2.5         # Spreadsheet-like UI widget
sv-ttk>=2.5.0          # Modern Tkinter theme
matplotlib>=3.0.0      # Plotting (for pandastable)
openpyxl>=3.0.0        # Excel export support
pillow>=8.0.0          # Image processing
```

## 🔄 Data Flow

```
[User Config] → [Python GUI] → [C Application] → [OpenCL Kernel] → [Template]
     ↑                                ↓               ↓              ↓
[Database] ← [Results Processing] ← [Host Memory] ← [GPU Results] ← [Scoring]
```

## 📝 File Naming Conventions

### Configuration Files
- Format: `{config_name}.ouija.json`
- Database: `{config_name}.db`
- Exports: `{config_name}_{timestamp}.csv`

### Build Outputs
- Standard: `Ouija.exe`
- Variants: `Ouija-{variant}.exe` (profile, optimized, etc.)

### Python Modules
- Snake case: `config_model.py`, `main_window.py`
- Package structure with `__init__.py` files

## 🚀 Entry Points

### C Application
```bash
# Direct execution
./Ouija.exe config_file.ouija.json

# With arguments
./Ouija.exe config_file.ouija.json --device 0 --verbose
```

### Python GUI
```bash
# Standard launch
python run_ouija_mvc.py

# Module launch
python -m ouija_mvc.app
```

### Build Process
```bash
# Configure
cmake -G "Visual Studio 17 2022" -A x64 -B ./build

# Build
cmake --build ./build --config Release
```

---

*This structure enables modular development, clear separation of concerns, and efficient collaboration between AI assistants and human developers.*
