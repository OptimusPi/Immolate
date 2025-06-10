# Code Patterns and Conventions

This document outlines established patterns and conventions used throughout the Immolate project.

## 🔧 OpenCL Patterns

### Struct Definition Pattern
Always define structs in both C and OpenCL with identical layouts:

```c
// lib/ouija_host_result.h (C version)
typedef struct OuijaHostResult {
    uint64_t seed;
    int ScoreWants[MAX_DESIRES_HOST];
    // ... other fields
} OuijaHostResult;
```

```opencl
// lib/ouija_result.cl (OpenCL version)
typedef struct OuijaResult {
    ulong seed;
    int ScoreWants[MAX_DESIRES_KERNEL];
    // ... other fields (MUST MATCH C!)
} OuijaResult;
```

### Wants Scoring Pattern
**✅ CORRECT**: Use conditional logic for wants scoring
```opencl
if (jokerMatch && condition) {
    result->ScoreWants[desireIndex] += 1;
}
```

**❌ WRONG**: Avoid boolean arithmetic (creates fractional wants)
```opencl
result->ScoreWants[desireIndex] += jokerMatch && condition;
```

### Array Initialization Pattern
Always explicitly initialize arrays:
```opencl
// Initialize ScoreWants array
for (int i = 0; i < MAX_DESIRES_KERNEL; i++) {
    result->ScoreWants[i] = 0;
}
```

### Duplicate Prevention Pattern (Showman Logic)
```opencl
bool jokerAlreadyScored = false;
for (int k = 0; k < j; k++) {
    if (availableJokers[k] == joker && scored[k]) {
        jokerAlreadyScored = true;
        break;
    }
}

// Only score if not already scored (unless Showman is active)
bool canScore = !jokerAlreadyScored || hasShowman;
if (canScore && /* other conditions */) {
    // Score the joker
}
```

### Negative Tag Application Pattern
```opencl
// Check if we can apply negative tag
bool canApplyNegativeTag = desire.NegativeTag && 
                          negativeTagApplications > 0 && 
                          /* other conditions */;

if (canApplyNegativeTag) {
    negativeTagApplications--; // Consume one application
    // Apply negative tag logic
}
```

## 🐍 Python MVC Patterns

### Model Pattern
Models handle data and business logic:
```python
class ConfigModel:
    def __init__(self):
        self.config_data = {}
        self.config_modified = False
        
    def load_config_from_path(self, file_path):
        """Load and validate configuration"""
        try:
            with open(file_path, 'r') as f:
                self.config_data = json.load(f)
            return True
        except Exception as e:
            print(f"Error loading config: {e}")
            return False
```

### View Pattern
Views handle UI components and user interaction:
```python
class MainWindow:
    def __init__(self, root, controller):
        self.root = root
        self.controller = controller
        self.controller.register_view(self)
        self.setup_ui()
        
    def update_config_display(self):
        """Update UI when model changes"""
        config = self.controller.get_current_config()
        # Update UI elements
```

### Controller Pattern
Controllers coordinate between models and views:
```python
class ApplicationController:
    def __init__(self, config_model, search_model, database_model):
        self.config_model = config_model
        self.search_model = search_model
        self.database_model = database_model
        self.current_view = None
        
    def register_view(self, view):
        """Register view for callbacks"""
        self.current_view = view
        
    def load_config(self, file_path):
        """Coordinate config loading"""
        success = self.config_model.load_config_from_path(file_path)
        if success and self.current_view:
            self.current_view.update_config_display()
        return success
```

### Callback Pattern
Use callbacks for model-view communication:
```python
# In model
class SearchModel:
    def set_callbacks(self, results_callback=None, console_callback=None):
        self.results_callback = results_callback
        self.console_callback = console_callback
        
    def _notify_results(self, results):
        if self.results_callback:
            self.results_callback(results)

# In controller
def _on_search_results(self, results):
    """Handle search results from model"""
    if self.current_view:
        self.current_view.update_results_display(results)
```

## 🗂️ File Organization Patterns

### Configuration Files
```
ouija_configs/
├── config_name.ouija.json     # Main config
├── config_name.wants          # Desires definitions
└── config_name.db             # Results database
```

### Python Module Structure
```python
# __init__.py files enable proper imports
from .models import ConfigModel, SearchModel, DatabaseModel
from .views import MainWindow
from .controllers import ApplicationController
```

### Import Patterns
```python
# Relative imports within package
from .models.config_model import ConfigModel
from ..utils.game_data import JOKER_DEFINITIONS

# External imports at top
import tkinter as tk
import json
import subprocess
```

## 🛠️ Error Handling Patterns

### Graceful Degradation
```python
try:
    result = risky_operation()
    return True, result
except SpecificException as e:
    logger.error(f"Specific error: {e}")
    return False, str(e)
except Exception as e:
    logger.error(f"Unexpected error: {e}")
    return False, "An unexpected error occurred"
```

### User Feedback Pattern
```python
def save_config(self, file_path=None):
    success, result = self.config_model.save_config(file_path)
    if success and self.current_view:
        self.current_view.set_status(f"Configuration saved: {result}")
    elif not success and self.current_view:
        messagebox.showerror("Error", f"Failed to save: {result}")
    return success
```

## 🔍 Debugging Patterns

### Console Output Pattern
```python
def _on_console_output(self, output):
    """Handle console output from search process"""
    if self.current_view:
        self.current_view.append_console_output(output)
```

### Process Cleanup Pattern
```python
def cleanup_ouija_processes():
    """Ensure all Ouija.exe processes are terminated"""
    try:
        if os.name == 'nt':  # Windows
            subprocess.call(['taskkill', '/F', '/IM', 'Ouija.exe'], 
                          stderr=subprocess.DEVNULL)
        else:  # Unix/Linux/Mac
            subprocess.call(['pkill', '-f', 'Ouija.exe'], 
                          stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Error cleaning up: {e}")

# Register cleanup handler
atexit.register(cleanup_ouija_processes)
```

## 🎯 Performance Patterns

### Debounced Updates
```python
def _schedule_ui_update(self):
    """Debounce UI updates to avoid overwhelming the interface"""
    if self.update_timer_id:
        self.current_view.root.after_cancel(self.update_timer_id)
    
    self.update_timer_id = self.current_view.root.after(
        self.update_debounce_ms, 
        self._perform_ui_update
    )
```

### Lazy Loading Pattern
```python
@property
def joker_definitions(self):
    """Lazy load joker definitions"""
    if not hasattr(self, '_joker_definitions'):
        self._joker_definitions = self._load_joker_definitions()
    return self._joker_definitions
```

## 📊 Data Validation Patterns

### Configuration Validation
```python
def validate_config(self, config_data):
    """Validate configuration structure"""
    required_fields = ['ConfigName', 'Desires', 'SearchMode']
    for field in required_fields:
        if field not in config_data:
            return False, f"Missing required field: {field}"
    
    if not isinstance(config_data['Desires'], list):
        return False, "Desires must be a list"
    
    return True, "Valid"
```

### Input Sanitization
```python
def sanitize_filename(self, filename):
    """Remove invalid characters from filename"""
    invalid_chars = '<>:"/\\|?*'
    for char in invalid_chars:
        filename = filename.replace(char, '_')
    return filename.strip()
```

---

*Follow these patterns for consistency and maintainability across the Immolate codebase.*
