"""
Database Model - Handles database interactions for Ouija seed finder
"""
import os
import duckdb
import pandas as pd
from pathlib import Path
import datetime

class DatabaseModel:
    """Model for handling database operations with DuckDB"""
    
    DB_DIR = "ouija_database"
    
    def __init__(self):
        """Initialize the database model"""
        self.conn = None
        self.current_db_path = None
        
        # Ensure database directory exists
        os.makedirs(self.DB_DIR, exist_ok=True)
    
    def get_db_path_from_config(self, config_path):
        """Derive database path from configuration path, always in ouija_database directory."""
        if not config_path:
            return None
        base = os.path.basename(config_path)
        name, _ = os.path.splitext(base)
        return os.path.join(self.DB_DIR, f"{name}.duckdb")
    
    def connect(self, config_path):
        """Connect to the database for a given configuration"""
        # Close any existing connection
        if self.conn:
            self.conn.close()
            self.conn = None

        # Get new db path
        db_path = self.get_db_path_from_config(config_path)
        if not db_path:
            return False

        try:
            # Connect to DuckDB
            self.conn = duckdb.connect(db_path)
            self.current_db_path = db_path

            # Ensure the results table exists
            if not self.table_exists():
                self.create_table(["Seed", "Score"])

            return True
        except Exception as e:
            print(f"Error connecting to database: {e}")
            return False
    
    def close(self):
        """Close the current database connection"""
        if self.conn:
            self.conn.close()
            self.conn = None
            self.current_db_path = None
    
    def create_table(self, columns):
        """Forcefully create the results table with the given columns."""
        if not self.conn:
            return False

        try:
            # Drop the table if it exists
            if self.table_exists():
                self.conn.execute("DROP TABLE IF EXISTS results")

            # Create the table with a strict schema:
            # - Seed is VARCHAR PRIMARY KEY
            # - All other columns are INTEGER
            columns_def = []
            for col in columns:
                if col == "Seed":
                    columns_def.append(f'"{col}" VARCHAR PRIMARY KEY')
                else:
                    columns_def.append(f'"{col}" INTEGER')

            # Create the table
            self.conn.execute(f"CREATE TABLE results ({', '.join(columns_def)});")

            # Create an index on the Score column for faster sorting
            if "Score" in columns:
                try:
                    self.conn.execute('CREATE INDEX IF NOT EXISTS idx_score ON results ("Score");')
                except Exception:
                    pass

            return True
        except Exception as e:
            print(f"Error forcefully creating table: {e}")
            return False

    def ensure_columns_exist(self, columns):
        """Ensure all specified columns exist in the results table."""
        if not self.conn or not self.table_exists():
            return False

        try:
            # Get existing columns
            existing_columns = [row[0] for row in self.conn.execute("PRAGMA table_info(results)").fetchall()]

            # Add missing columns or recreate the table if a conflict occurs
            for col in columns:
                if col not in existing_columns:
                    try:
                        self.conn.execute(f'ALTER TABLE results ADD COLUMN "{col}" INTEGER;')
                    except Exception as e:
                        if "already exists" in str(e):
                            print("Column conflict detected. Recreating the table.")
                            self.create_table(columns)
                            break

            return True
        except Exception as e:
            print(f"Error ensuring columns exist: {e}")
            self.create_table(columns)  # Recreate the table on error
            return False

    def insert_result(self, columns, values):
        """Insert a result row into the database"""
        if not self.conn:
            return False

        try:
            # Ensure all columns exist in the table
            if not self.table_exists():
                print("Table 'results' does not exist. Recreating the table.")
                self.create_table(columns)

            self.ensure_columns_exist(columns)

            # Use Seed column as the unique key for upsert
            seed_value = values[0] if values else None
            if not seed_value:
                return False

            # Create column names and placeholder values for the SQL statement
            column_names = ', '.join([f'"{col}"' for col in columns])
            placeholders = ', '.join(['?'] * len(values))

            # Insert or replace the row
            query = f'INSERT OR REPLACE INTO results ({column_names}) VALUES ({placeholders})'
            self.conn.execute(query, values)

            return True
        except Exception as e:
            print(f"Error upserting result: {e}")
            return False
    
    def query_results(self, sort_column="Score", descending=True, limit=1000):
        """Query results from the database, optionally sorted and limited
        
        Args:
            sort_column: Column to sort by (default: "Score")
            descending: Sort in descending order (default: True)
            limit: Maximum number of results to return (default: 1000)
        """
        if not self.conn:
            return None
            
        try:
            # Check if the results table exists
            table_exists = self.conn.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'results'").fetchone()[0]
            if not table_exists:
                return None
                
            # Query with optional sorting, limited to top 1000 results by default
            direction = "DESC" if descending else "ASC"
            result = self.conn.execute(f'SELECT * FROM results ORDER BY "{sort_column}" {direction} LIMIT {limit}').fetch_df()
            return result
        except Exception as e:
            print(f"Error querying results: {e}")
            return None
    
    def get_dataframe(self):
        """Get results as a pandas DataFrame"""
        return self.query_results()
    
    def table_exists(self):
        """Check if the results table exists in the current database"""
        if not self.conn:
            return False
            
        try:
            result = self.conn.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'results'").fetchone()[0]
            return result > 0
        except Exception as e:
            print(f"Error checking table existence: {e}")
            return False

    def process_csv_line(self, line, header_columns=None):
        """Process a CSV line directly from string"""
        if not self.conn:
            return None
            
        try:
            # Remove the leading '|' character
            if line.startswith('|'):
                csv_line = line[1:].strip()
            else:
                csv_line = line.strip()
            
            # Split by comma
            parts = csv_line.split(',')
            
            # Process values strictly according to our model:
            # - First value (Seed) is STRING
            # - All other values are INTEGER
            values = []
            for i, part in enumerate(parts):
                if i == 0:  # Seed column
                    values.append(part.strip())  # String value
                else:  # All other columns
                    try:
                        # Force integer conversion - truncate any decimal part
                        part_str = part.strip()
                        if '.' in part_str:
                            part_str = part_str.split('.')[0]
                        values.append(int(part_str))
                    except ValueError:
                        values.append(0)  # Default to 0 if conversion fails
            
            # Use provided header columns or generate default ones
            if header_columns is None:
                header_columns = ["Seed"]
                header_columns.extend([f"Col{i}" for i in range(1, len(values))])
            
            # Ensure values match header length
            if len(values) < len(header_columns):
                values.extend([0] * (len(header_columns) - len(values)))
            elif len(values) > len(header_columns):
                values = values[:len(header_columns)]
            
            return header_columns, values
        except Exception as e:
            print(f"Error processing CSV line: {e}")
            return None