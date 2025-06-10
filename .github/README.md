# 🤖 AI Assistant Guide for Immolate

Welcome, AI assistant! This guide will help you understand and work effectively with the Immolate project.

## 🚀 Quick Start for AI

### What is Immolate?
Immolate is an **OpenCL-powered seed searcher for Balatro**, a roguelike deckbuilder game. It finds optimal starting seeds based on desired joker combinations and game conditions.

### Core Components
1. **C/OpenCL Engine** (`ouija.c` + `*.cl`) - High-performance seed searching
2. **Python GUI** (`ouija_mvc/`) - User-friendly configuration and results management  
3. **Configuration System** (`.ouija.json` files) - Define search criteria

## 📚 Essential Reading Order

1. **Start Here**: [`AI_COLLABORATION_GUIDE.md`](AI_COLLABORATION_GUIDE.md) - Core concepts and architecture
2. **Patterns**: [`CODE_PATTERNS.md`](CODE_PATTERNS.md) - Established coding conventions
3. **Structure**: [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) - File organization details
4. **Debugging**: [`AI_TROUBLESHOOTING.md`](AI_TROUBLESHOOTING.md) - Common issues and solutions
5. **Refactoring**: [`REFACTORING_PLAN.md`](REFACTORING_PLAN.md) - Current improvement roadmap

## ⚡ Common Tasks & Quick Refs

### 🔧 OpenCL Template Fixes
```opencl
// Always initialize ScoreWants array
for (int i = 0; i < MAX_DESIRES_KERNEL; i++) {
    result->ScoreWants[i] = 0;
}

// Use conditional logic, NOT boolean arithmetic
if (jokerMatch && condition) {
    result->ScoreWants[x] += 1;  // ✅ Correct
}
// NOT: result->ScoreWants[x] += jokerMatch && condition;  // ❌ Wrong
```

### 🐍 Python MVC Patterns
```python
# Controller coordination pattern
class SomeController:
    def some_operation(self, data):
        try:
            result = self.model.process(data)
            if self.view:
                self.view.update_display(result)
            return Result.success(result)
        except Exception as e:
            return Result.error(str(e))

# Callback registration pattern  
self.search_model.set_callbacks(
    results_callback=self._on_search_results,
    console_callback=self._on_console_output
)
```

### 🔍 Debugging Checklist
- [ ] Are `ScoreWants` arrays initialized?
- [ ] Is boolean arithmetic avoided in wants scoring?
- [ ] Do C and OpenCL structs match exactly?
- [ ] Are callbacks properly registered?
- [ ] Is error handling graceful?

## 🎯 Current Focus Areas

### ✅ Recently Fixed
- **Scoring Issues**: Fixed uninitialized arrays and boolean arithmetic bugs
- **CSV Export**: Resolved phantom column issues
- **Negative Tag Logic**: Fixed double consumption in anaglyph template

### 🔄 Active Work
- **MVC Refactoring**: Decomposing large controller, adding service layer
- **AI Documentation**: Creating comprehensive guides (you're reading one!)
- **Testing Framework**: Adding unit tests for better reliability

### 📋 Upcoming Features
- **FEAT 1**: Unified criteria editing dialog with tabs
- **Enhanced UI**: Better user experience for configuration management
- **Performance**: OpenCL optimization and profiling

## 🛠️ Development Workflow

### Making Changes
1. **Read Context**: Check relevant documentation first
2. **Understand Patterns**: Follow established conventions
3. **Test Early**: Use `chadtester.ouija.json` for validation
4. **Verify Results**: Ensure no regressions

### Adding Features
1. **Models First**: Define data structures and business logic
2. **Controllers Next**: Add coordination logic
3. **Views Last**: Update UI components
4. **Test Integration**: Verify end-to-end functionality

### Debugging Issues
1. **Isolate Problem**: Use minimal test cases
2. **Check Initialization**: Verify arrays and variables
3. **Trace Logic**: Follow execution path
4. **Compare Known-Good**: Diff against working code

## 📁 Key Files to Know

### Critical for Scoring Logic
- `filters/ouija_template.cl` - Main scoring template
- `filters/ouija_template_anaglyph.cl` - Anaglyph variant  
- `lib/ouija_host_result.h` - C struct definitions
- `lib/ouija_result.cl` - OpenCL struct definitions (must match C!)

### Python MVC Core
- `ouija_mvc/controllers/application_controller.py` - Main coordinator
- `ouija_mvc/models/` - Data models (config, search, database)
- `ouija_mvc/views/main_window.py` - Primary UI

### Configuration & Testing
- `ouija_configs/chadtester.ouija.json` - Test configuration
- `run_ouija_mvc.py` - GUI application launcher
- `ouija.c` - Core C application

## 🚨 Critical Warnings

### Struct Alignment
**🔥 NEVER** modify structs without updating both C and OpenCL versions!
- Changes in `lib/ouija_host_result.h` require matching changes in `lib/ouija_result.cl`
- Test with `check_layout.c` after modifications

### Boolean Arithmetic
**🔥 AVOID** boolean arithmetic in OpenCL wants scoring:
```opencl
// This creates 0.0 or 1.0 values that get truncated to 0!
result->ScoreWants[x] += condition1 && condition2;  // ❌ DON'T DO THIS
```

### CSV Output
**🔥 CHECK** CSV formatting when adding new result fields:
- No trailing commas on last field
- Headers must match data column count exactly

## 🎮 Game Knowledge Primer

### Balatro Basics
- **Jokers**: Special cards that modify scoring and game mechanics
- **Negative Tags**: Allow multiple copies of jokers (Anaglyph deck specific)
- **Showman Joker**: Allows joker duplicates in standard scoring
- **The Soul**: Spectral card that creates negative tags

### Search Concepts
- **Seeds**: RNG starting points that determine card/joker availability
- **Wants**: Desired joker counts for optimal gameplay
- **Templates**: Different scoring rules for different game variants

## 🔗 Quick Links

- **Build Project**: Use VS Code task "Build Ouija (Incremental)"
- **Run Tests**: `python -m pytest ouija_mvc/tests/` (after refactoring)
- **Check Structs**: `gcc check_layout.c && ./a.out`
- **Launch GUI**: `python run_ouija_mvc.py`

## 💡 Pro Tips for AI

1. **Pattern Recognition**: Look for similar code patterns before implementing new features
2. **Error Context**: Always provide user-friendly error messages with context
3. **Performance Awareness**: Consider GPU memory bandwidth in OpenCL code
4. **Documentation**: Update relevant docs when making significant changes
5. **Test Driven**: Write tests for new functionality when possible

---

**Remember**: This project combines high-performance computing (OpenCL) with user-friendly interfaces (Python/Tkinter). Always consider both performance and usability when making changes.

*Happy coding! 🚀*
