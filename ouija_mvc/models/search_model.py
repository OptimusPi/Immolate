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
        "1": "1",
        "32": "32",
        "64": "64",
        "128": "128",
        "256": "256"
    }
    
    SEED_COUNT_MAP = {
        "All Seeds": None,  # Use None to indicate omitting the argument
        "1": "1",
        "1K": "1000",
        "100K": "100000",
        "1M": "1000000",
        "100M": "100000000",
        "1B": "1000000000",
        "10B": "10000000000",
        "100B": "100000000000",
    }
    
    def __init__(self):
        """Initialize the search model"""
        self.active_processes = []
        self.results_callback = None
        self.console_callback = None
        self.process_finished_callback = None
        self.cutoff = None  # Add cutoff
        self.gpu_batch = None  # Add gpu_batch
        
    def build_command(self, config_path, starting_seed, thread_groups, number_of_seeds, template=None):
        """Build the command to execute with proper arguments"""
        # Construct the base command
        command_parts = [".\\Ouija.exe"]
        
        # Add template filter if provided
        if template:
            command_parts.extend(["-f", template])
        
        # Add starting seed - handle both "random" and user-entered seeds
        # Convert to uppercase for consistency with Balatro's seed format
        if starting_seed.lower() == "random" or not starting_seed.strip():
            command_parts.extend(["-s", "random"])
        else:
            command_parts.extend(["-s", starting_seed.upper()])
            
        # Add thread groups
        thread_groups_value = self.THREAD_GROUP_MAP.get(thread_groups, "32")
        command_parts.extend(["-g", thread_groups_value])
        
        # Add number of seeds if specified
        number_of_seeds_value = self.SEED_COUNT_MAP.get(number_of_seeds)
        if number_of_seeds_value is not None:
            command_parts.extend(["-n", number_of_seeds_value])
        # Skip adding -n if number_of_seeds_value is None (for 'All')
        
        # Add config path if provided
        if config_path:
            command_parts.extend(["--config", f'"{config_path}"'])
        
        # Add cutoff if provided
        if self.cutoff:
            command_parts.extend(["-c", str(self.cutoff)])
        
        # Add gpu_batch if provided
        if self.gpu_batch:
            command_parts.extend(["-b", str(self.gpu_batch)])
        
        # Join parts into the final command string
        command = " ".join(command_parts)
        return command
    
    def set_callbacks(self, results_callback=None, console_callback=None, process_finished_callback=None):
        """Set callbacks for handling search results and output"""
        self.results_callback = results_callback
        self.console_callback = console_callback
        self.process_finished_callback = process_finished_callback
    
    def start_search(self, config_path, starting_seed, thread_groups, number_of_seeds, db_model, cutoff=None, gpu_batch=None, template=None):
        """Start the search process with the given parameters, including cutoff, gpu_batch, and template."""
        self.cutoff = cutoff
        self.gpu_batch = gpu_batch
        command = self.build_command(config_path, starting_seed, thread_groups, number_of_seeds, template)
        
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
        db_table_created = False
        last_db_ping_time = time.time()
        db_ping_interval = 1.0  # Notify controller every 1 second that new data might be in DB

        # If we already have results in the database, we don't need to load them here.
        # The controller will handle refreshing from DB.
        if db_model and db_model.conn and db_model.table_exists():
            db_table_created = True  # Assume table structure is known if DB exists
            # Try to get headers if table exists, to avoid issues if Ouija.exe doesn't print them
            try:
                existing_df = db_model.query_results(limit=1)  # Changed from get_dataframe(limit=1)
                if existing_df is not None and not existing_df.empty:
                    header_columns = existing_df.columns.tolist()
                    header_found = True
            except Exception as e:
                if self.console_callback:
                    self.console_callback(f"Error getting headers from existing DB: {str(e)}\n")

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
                if not header_found and line.strip().startswith("+Seed,"):
                    # Validate headers to ensure they are distinct and valid
                    header_columns = [col.strip() for col in line.replace("+Seed", "Seed").strip().replace(" ","_").replace("!","").split(",") if col.strip() != ""]
                    
                    # Relax header validation to allow duplicates but log a warning
                    if len(header_columns) != len(set(header_columns)):
                        if self.console_callback:
                            self.console_callback(f"Warning: Duplicate headers found: {header_columns}\n")
                    # Validate header names but do not raise an error for invalid ones
                    invalid_headers = [col for col in header_columns if not col.isidentifier()]
                    if invalid_headers:
                        if self.console_callback:
                            self.console_callback(f"Warning: Invalid header names found: {invalid_headers}\n")

                    header_found = True

                    # Create table in database
                    if db_model and db_model.conn and not db_table_created:
                        db_model.create_table(header_columns)
                        db_table_created = True
                    
                    continue

                # Process result lines (those starting with '|')
                if line.startswith("|"):
                    if not header_columns:  # Wait for header
                        if self.console_callback:
                            self.console_callback(f"Skipping result line, header not yet found: {line.strip()}\n")
                        continue
                        
                    try:
                        # Process the CSV line directly using DuckDB's CSV parser
                        result = db_model.process_csv_line(line, header_columns)
                            
                        if not result:
                            continue
                            
                        # Unpack the result
                        parsed_headers, parsed_values = result
                        
                        # If we didn't have headers before, use the ones from parsing (should not happen if logic above is correct)
                        if not header_columns:
                            header_columns = parsed_headers
                            if db_model and db_model.conn and not db_table_created:
                                db_model.create_table(header_columns)
                                db_table_created = True
                        
                        # Store in database using upsert
                        if db_model and db_model.conn and db_table_created:
                            db_model.insert_result(header_columns, parsed_values)
                        
                        # Periodically notify controller to refresh from DB
                        current_time = time.time()
                        if (current_time - last_db_ping_time) >= db_ping_interval:
                            if self.results_callback:  # This callback now signals to refresh from DB
                                self.results_callback(None, None)  # Pass None, None as data is in DB
                                last_db_ping_time = current_time
                    except Exception as e:
                        if self.console_callback:
                            self.console_callback(f"Error processing CSV line for DB insertion: {str(e)}\n")
                
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

            # Make sure to send one final notification to controller after process ends
            if self.results_callback:
                self.results_callback(None, None)

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