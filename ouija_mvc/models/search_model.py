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
                text=False,  # Changed to False to receive bytes instead of text
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
        result_rows = []  # This will store all accumulated results
        db_table_created = False
        last_update_time = time.time()
        update_interval = 1.0  # Update UI at most every 1 second
        results_updated = False
        
        # If we already have results in the database, load them
        if db_model and db_model.conn and db_model.table_exists():
            try:
                df = db_model.get_dataframe()
                if df is not None and not df.empty:
                    # Convert dataframe rows to list format
                    header_columns = df.columns.tolist()
                    # Convert DataFrame values to properly typed list of lists
                    result_rows = []
                    for _, row in df.iterrows():
                        # Ensure consistent typing: all values except Seed are converted to int or 0
                        typed_row = []
                        for col_idx, value in enumerate(row):
                            if col_idx == 0:  # First column is Seed, keep as string
                                typed_row.append(str(value))
                            else:  # Other columns should be integers
                                try:
                                    typed_row.append(int(value) if value is not None else 0)
                                except (ValueError, TypeError):
                                    typed_row.append(0)  # Fallback to 0 if conversion fails
                        result_rows.append(typed_row)
                    db_table_created = True
            except Exception as e:
                if self.console_callback:
                    self.console_callback(f"Error loading existing results: {str(e)}\n")
        
        try:
            while True:
                # Check if process has terminated
                if process.poll() is not None:
                    break
                
                # Read a line from stdout as bytes and decode with error handling
                line_bytes = process.stdout.readline()
                if not line_bytes:
                    break
                
                # Try multiple encodings
                line = None
                for encoding in ['utf-8', 'latin-1', 'cp1252']:
                    try:
                        line = line_bytes.decode(encoding)
                        break
                    except UnicodeDecodeError:
                        continue
                
                # If all encodings fail, use 'latin-1' as a fallback with error replacement
                if line is None:
                    line = line_bytes.decode('latin-1', errors='replace')

                # Parse CSV header
                if not header_found and line.strip().startswith("Seed,"):
                    header_columns = [col.strip() for col in line.strip().split(",") if col.strip() != ""]
                    header_found = True
                    
                    # Create table in database
                    if db_model and db_model.conn and not db_table_created:
                        db_model.create_table(header_columns)
                        db_table_created = True
                    
                    continue
                
                # Process result lines (those starting with '|')
                if line.startswith("|"):
                    try:
                        # Process the CSV line directly using DuckDB's CSV parser
                        result = db_model.process_csv_line(line, header_columns)
                            
                        if not result:
                            continue
                            
                        # Unpack the result
                        parsed_headers, parsed_values = result
                        
                        # If we didn't have headers before, use the ones from parsing
                        if not header_columns:
                            header_columns = parsed_headers
                            
                            # Create table if needed
                            if db_model and db_model.conn and not db_table_created:
                                db_model.create_table(header_columns)
                                db_table_created = True
                        
                        # Store in database using upsert
                        if db_model and db_model.conn:
                            db_model.insert_result(header_columns, parsed_values)
                        
                        # Update in-memory results
                        # Check if this seed already exists in our results
                        seed = parsed_values[0] if parsed_values else ""
                        found = False
                        
                        for i, row in enumerate(result_rows):
                            if row[0] == seed:
                                # Update the existing row
                                result_rows[i] = parsed_values
                                found = True
                                break
                                
                        # Add new row if not found
                        if not found:
                            result_rows.append(parsed_values)
                        
                        # Mark that we have new results to display
                        results_updated = True
                        
                        # Only update UI at most once per second
                        current_time = time.time()
                        if (current_time - last_update_time) >= update_interval:
                            if self.results_callback and header_columns:
                                self.results_callback(header_columns, result_rows)
                                last_update_time = current_time
                                results_updated = False
                    except Exception as e:
                        if self.console_callback:
                            self.console_callback(f"Error processing CSV line: {str(e)}\n")
                
                # Handle status bar messages (lines starting with "$")
                elif line.startswith("$") and line.strip() != "$":
                    # Pass status messages to the application controller via console callback
                    # with a special prefix that the controller will recognize
                    if self.console_callback:
                        # Strip the "$" and any whitespace
                        status_message = line.strip()[1:].strip()
                        
                        # Format metrics with clock emoji at the end for right-alignment
                        # Example: "Elapsed time: 12.3 seconds, Estimated remaining time: 45.6 seconds ⏱️123.4K/s"
                        if "$clock$" in status_message:
                            parts = status_message.split("$clock$")
                            status_message = f"{parts[0].strip()} ⏱️{parts[1].strip()}"
                        
                        self.console_callback(f"STATUS:{status_message}\n")

            # Make sure to update UI with final results if there are pending updates
            if results_updated and self.results_callback and header_columns:
                self.results_callback(header_columns, result_rows)

            # Process stderr after stdout is done
            for line_bytes in process.stderr:
                # Decode stderr bytes with error handling
                try:
                    line = line_bytes.decode('utf-8')
                except UnicodeDecodeError:
                    line = line_bytes.decode('latin-1', errors='replace')
                
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
        # First try to stop the processes we're tracking
        for process in self.active_processes:
            try:
                if process.poll() is None:  # If process is still running
                    if os.name == 'nt':  # Windows
                        subprocess.call(['taskkill', '/F', '/T', '/PID', str(process.pid)])
                    else:  # Unix/Linux/Mac
                        os.kill(process.pid, signal.SIGKILL)
            except Exception as e:
                print(f"Error stopping process: {e}")
        
        # Also look for any Ouija.exe processes that might have been left behind
        try:
            if os.name == 'nt':  # Windows
                # Kill any remaining Ouija.exe processes
                subprocess.call(['taskkill', '/F', '/IM', 'Ouija.exe'], stderr=subprocess.DEVNULL)
            else:  # Unix/Linux/Mac
                # Find and kill any Ouija processes
                subprocess.call(['pkill', '-f', 'Ouija.exe'], stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"Error cleaning up Ouija processes: {e}")
        
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