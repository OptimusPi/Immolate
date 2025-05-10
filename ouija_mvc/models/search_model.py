"""
Search Model - Handles search process logic for Ouija seed finder
"""
import os
import subprocess
import threading
import time
import signal

class SearchModel:
    """Model for handling seed search operations"""
    
    # Maps for dropdown values to command-line arguments
    THREAD_GROUP_MAP = {
        "Single": "1",
        "Default (16)": "16",
        "32": "32",
        "48": "48",
        "56": "56",
        "64": "64",
        "96": "96",
        "112": "112",
        "128": "128",
        "224": "224",
        "256": "256"
    }
    
    SEED_COUNT_MAP = {
        "Single (1)": "1",
        "Default (All Seeds)": None,  # Use None to indicate omitting the argument
        "1K": "1000",
        "100K": "100000",
        "1M": "1000000",
        "100M": "100000000",
        "1B": "1000000000"
    }
    
    def __init__(self):
        """Initialize the search model"""
        self.active_processes = []
        self.results_callback = None
        self.console_callback = None
        self.process_finished_callback = None
    
    def build_command(self, config_path, starting_seed, thread_groups, number_of_seeds):
        """Build the command to execute with proper arguments"""
        # Construct the base command
        command_parts = [".\\Ouija.exe"]
        
        # Add starting seed
        command_parts.extend(["-s", starting_seed])
        
        # Add thread groups
        thread_groups_value = self.THREAD_GROUP_MAP.get(thread_groups, "16")
        command_parts.extend(["-g", thread_groups_value])
        
        # Add number of seeds if specified
        number_of_seeds_value = self.SEED_COUNT_MAP.get(number_of_seeds)
        if number_of_seeds_value is not None:
            command_parts.extend(["-n", number_of_seeds_value])
        
        # Add config path if provided
        if config_path:
            command_parts.extend(["--config", f'"{config_path}"'])
        
        # Join parts into the final command string
        command = " ".join(command_parts)
        return command
    
    def set_callbacks(self, results_callback=None, console_callback=None, process_finished_callback=None):
        """Set callbacks for handling search results and output"""
        self.results_callback = results_callback
        self.console_callback = console_callback
        self.process_finished_callback = process_finished_callback
    
    def start_search(self, config_path, starting_seed, thread_groups, number_of_seeds, db_model):
        """Start the search process with the given parameters"""
        command = self.build_command(config_path, starting_seed, thread_groups, number_of_seeds)
        
        # Log the command
        if self.console_callback:
            self.console_callback(f"Executing: {command}\n")
        
        try:
            # Start the process
            process = subprocess.Popen(
                command, 
                shell=True, 
                stdout=subprocess.PIPE, 
                stderr=subprocess.PIPE, 
                text=True, 
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            
            # Add to active processes
            self.active_processes.append(process)
            
            # Start a thread to read the output
            thread = threading.Thread(
                target=self._read_process_output,
                args=(process, db_model),
                daemon=True
            )
            thread.start()
            
            return True
        except Exception as e:
            if self.console_callback:
                self.console_callback(f"Error starting search: {str(e)}\n")
            return False
    
    def _read_process_output(self, process, db_model):
        """Read and process output from the search command"""
        header_columns = None
        header_found = False
        result_rows = []
        
        try:
            while True:
                # Check if process has terminated
                if process.poll() is not None:
                    break
                
                # Read a line from stdout
                line = process.stdout.readline()
                if not line:
                    break
                
                # Send line to console
                if self.console_callback:
                    self.console_callback(line)
                
                # Parse CSV header
                if not header_found and line.strip().startswith("Seed,"):
                    header_columns = [col.strip() for col in line.strip().split(",") if col.strip() != ""]
                    header_found = True
                    
                    # Create table in database
                    if db_model and db_model.conn:
                        db_model.create_table(header_columns)
                    
                    continue
                
                # Process result lines (those starting with '|')
                if line.startswith("|"):
                    if not header_columns:
                        # Fallback for missing headers
                        parts = line[1:].strip().split(",")
                        header_columns = [f"col{i+1}" for i in range(len(parts))]
                        
                        # Create table if needed
                        if db_model and db_model.conn and not db_model.table_exists():
                            db_model.create_table(header_columns)
                    
                    # Extract data from the line
                    parts = line[1:].strip().split(",")
                    
                    # Store in database
                    if db_model and db_model.conn:
                        db_model.insert_result(header_columns, parts)
                    
                    # Add to results for immediate display
                    result_rows.append(parts)
                    
                    # Update the UI if we have a results callback
                    if self.results_callback and header_columns:
                        self.results_callback(header_columns, result_rows)
                if line.startswith("$"):
                    # Status Bar message
                    self.status_bar.set_status(line[1:].strip())

            # Process stderr after stdout is done
            for line in process.stderr:
                if self.console_callback:
                    self.console_callback(f"ERROR: {line}")
            
            # Remove process from active list
            if process in self.active_processes:
                self.active_processes.remove(process)
            
            # Call process finished callback
            if self.process_finished_callback:
                self.process_finished_callback()
                
        except Exception as e:
            if self.console_callback:
                self.console_callback(f"Error processing output: {str(e)}\n")
            
            # Call process finished callback on error
            if self.process_finished_callback:
                self.process_finished_callback()
    
    def stop_all_searches(self):
        """Stop all active search processes"""
        for process in self.active_processes:
            try:
                if process.poll() is None:  # If process is still running
                    if os.name == 'nt':  # Windows
                        subprocess.call(['taskkill', '/F', '/T', '/PID', str(process.pid)])
                    else:  # Unix/Linux/Mac
                        os.kill(process.pid, signal.SIGKILL)
            except Exception as e:
                print(f"Error stopping process: {e}")
        
        # Clear the list
        self.active_processes.clear()
        
        # Call process finished callback
        if self.process_finished_callback:
            self.process_finished_callback()
            
        return True
    
    def has_active_searches(self):
        """Check if there are any active search processes"""
        # Remove any completed processes
        self.active_processes = [p for p in self.active_processes if p.poll() is None]
        return len(self.active_processes) > 0