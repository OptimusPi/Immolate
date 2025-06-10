# AI Development Troubleshooting Guide

Common issues encountered during AI-assisted development and their solutions.

## 🔧 OpenCL Template Issues

### ❌ Problem: Positive Jokers Show 0 Wants, Negatives Work Fine
**Symptoms**:
- Jokers like "Hanging Chad" show `ScoreWants[x] = 0`
- Negative variants score correctly
- CSV output may have extra columns

**Root Causes & Solutions**:

1. **Uninitialized ScoreWants Array**
   ```opencl
   // ❌ Missing initialization
   void score_seed(...) {
       // ScoreWants array contains garbage values
   }
   
   // ✅ Proper initialization  
   void score_seed(...) {
       for (int i = 0; i < MAX_DESIRES_KERNEL; i++) {
           result->ScoreWants[i] = 0;
       }
   }
   ```

2. **Boolean Arithmetic in Wants Scoring**
   ```opencl
   // ❌ Creates fractional wants (0.0 or 1.0, truncated to 0)
   result->ScoreWants[x] += jokerMatch && condition;
   
   // ✅ Proper conditional logic
   if (jokerMatch && condition) {
       result->ScoreWants[x] += 1;
   }
   ```

3. **Double Consumption of Negative Tag Applications**
   ```opencl
   // ❌ Consuming negativeTagApplications twice
   if (desire.NegativeTag && negativeTagApplications > 0) {
       negativeTagApplications--; // First consumption
   }
   // Later in wants scoring...
   if (desire.NegativeTag && negativeTagApplications > 0) {
       negativeTagApplications--; // Second consumption (BUG!)
   }
   
   // ✅ Consume only once, track state
   bool canApplyNegativeTag = desire.NegativeTag && negativeTagApplications > 0;
   if (canApplyNegativeTag) {
       negativeTagApplications--;
       // Use canApplyNegativeTag for wants scoring
   }
   ```

4. **CSV Output Formatting**
   ```c
   // ❌ Extra comma creates phantom column
   printf_s("%d,", result->NaturalNegativeJokers);
   
   // ✅ No trailing comma for last field
   printf_s("%d", result->NaturalNegativeJokers);
   ```

### ❌ Problem: Struct Alignment Issues
**Symptoms**:
- Garbage data in results
- Crashes or unexpected behavior
- Different results between debug/release builds

**Solution**: Verify struct definitions match exactly
```c
// lib/ouija_host_result.h
typedef struct OuijaHostResult {
    uint64_t seed;                    // 8 bytes
    int ScoreWants[MAX_DESIRES_HOST]; // 4 * count bytes
    // ... (must match OpenCL exactly)
} OuijaHostResult;
```

```opencl
// lib/ouija_result.cl  
typedef struct OuijaResult {
    ulong seed;                         // 8 bytes
    int ScoreWants[MAX_DESIRES_KERNEL]; // 4 * count bytes  
    // ... (must match C exactly)
} OuijaResult;
```

**Testing**: Use `check_layout.c` to verify alignment:
```bash
gcc check_layout.c && ./a.out
```

### ❌ Problem: Showman Duplicate Logic Errors
**Symptoms**:
- Jokers scored multiple times when they shouldn't be
- Inconsistent scoring between runs

**Solution**: Implement proper duplicate prevention
```opencl
bool jokerAlreadyScored = false;
for (int k = 0; k < j; k++) {
    if (availableJokers[k] == joker && scored[k]) {
        jokerAlreadyScored = true;
        break;
    }
}

// Only score if not already scored OR Showman is active
bool canScore = !jokerAlreadyScored || hasShowman;
if (canScore && /* other conditions */) {
    scored[j] = true; // Mark as scored
    // Perform scoring logic
}
```

## 🐍 Python MVC Issues

### ❌ Problem: Model-View Tight Coupling
**Symptoms**:
- Views directly accessing model data
- Difficulty testing components in isolation
- Changes to one component break others

**Solution**: Use controller as intermediary
```python
# ❌ View directly accessing model
class MainWindow:
    def update_display(self):
        data = self.config_model.config_data  # Direct access
        
# ✅ View accessing through controller
class MainWindow:
    def update_display(self):
        data = self.controller.get_current_config()  # Proper separation
```

### ❌ Problem: Callback Hell in Async Operations
**Symptoms**:
- Complex nested callbacks
- Difficult to trace execution flow
- Race conditions

**Solution**: Use structured callback pattern
```python
class SearchModel:
    def set_callbacks(self, results_callback=None, console_callback=None, finished_callback=None):
        self.callbacks = {
            'results': results_callback,
            'console': console_callback, 
            'finished': finished_callback
        }
    
    def _notify(self, event_type, data):
        if event_type in self.callbacks and self.callbacks[event_type]:
            self.callbacks[event_type](data)
```

### ❌ Problem: Memory Leaks in Long-Running Searches
**Symptoms**:
- Memory usage grows over time
- Application becomes sluggish
- System performance degrades

**Solution**: Proper cleanup patterns
```python
def cleanup_search(self):
    """Clean up search resources"""
    if self.search_process:
        self.search_process.terminate()
        self.search_process = None
    
    # Clear result buffers
    self.result_buffer.clear()
    
    # Cancel pending timers
    if self.update_timer_id:
        self.root.after_cancel(self.update_timer_id)
        self.update_timer_id = None
```

## 🔍 Debugging Strategies

### OpenCL Debugging
1. **Isolate the Template**: Test with minimal configuration
2. **Check Initialization**: Verify all arrays are properly initialized
3. **Trace Logic Flow**: Add debug prints to identify where logic fails
4. **Compare Templates**: Diff working vs. broken templates

```opencl
// Debug pattern for wants scoring
printf("Joker %d: match=%d, condition=%d, wants_before=%d\n", 
       joker, jokerMatch, condition, result->ScoreWants[x]);
       
if (jokerMatch && condition) {
    result->ScoreWants[x] += 1;
    printf("Wants incremented to %d\n", result->ScoreWants[x]);
}
```

### Python Debugging
1. **Use Logging**: Structured logging over print statements
2. **Test Components**: Isolate and test models/views separately
3. **Check Callbacks**: Verify callback registration and execution

```python
import logging
logging.basicConfig(level=logging.DEBUG)

class ConfigModel:
    def load_config(self, path):
        logging.debug(f"Loading config from {path}")
        try:
            # ... load logic
            logging.info(f"Config loaded successfully: {self.config_name}")
        except Exception as e:
            logging.error(f"Failed to load config: {e}")
```

## 📊 Testing Approaches

### Unit Testing Pattern
```python
# test_config_model.py
import unittest
from ouija_mvc.models.config_model import ConfigModel

class TestConfigModel(unittest.TestCase):
    def setUp(self):
        self.model = ConfigModel()
        
    def test_load_valid_config(self):
        success = self.model.load_config_from_path("test_config.json")
        self.assertTrue(success)
        self.assertEqual(self.model.config_name, "Test Config")
```

### Integration Testing with Known Configs
Use `chadtester.ouija.json` for consistent testing:
```bash
# Test specific joker scoring
./Ouija.exe ouija_configs/chadtester.ouija.json
```

### Regression Testing
1. Save known-good results
2. Compare new results against baseline
3. Investigate any differences

## 🚀 Performance Optimization

### OpenCL Performance
- **Memory Access Patterns**: Minimize divergent branching
- **Workgroup Size**: Experiment with different sizes
- **Memory Bandwidth**: Consider coalesced access patterns

### Python Performance  
- **UI Updates**: Debounce rapid updates
- **Large Datasets**: Use pagination or lazy loading
- **Process Communication**: Buffer results before UI updates

```python
def _schedule_ui_update(self):
    """Debounce UI updates"""
    if self.update_timer_id:
        self.root.after_cancel(self.update_timer_id)
    self.update_timer_id = self.root.after(500, self._perform_update)
```

## 🔧 Common Fix Patterns

### For Scoring Issues:
1. Check array initialization
2. Verify boolean arithmetic
3. Test with minimal config
4. Compare against working template

### For Python Issues:
1. Check model-view separation
2. Verify callback registration
3. Test component isolation
4. Review error handling

### For Build Issues:
1. Check struct alignment
2. Verify CMake configuration
3. Test with different compilers
4. Review dependency versions

---

*When encountering issues, start with the simplest possible test case and gradually add complexity until the problem is isolated.*
