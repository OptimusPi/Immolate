"""
Database Model - Handles database interactions for Ouija seed finder
"""
import os
import duckdb
import pandas as pd
from pathlib import Path

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
        """Create the results table with the given columns"""
        if not self.conn:
            return False
            
        try:
            columns_def = []
            for col in columns:
                if col == "Seed":
                    columns_def.append(f'"{col}" VARCHAR')
                else:
                    columns_def.append(f'"{col}" INTEGER')
            
            self.conn.execute(f"CREATE TABLE IF NOT EXISTS results ({', '.join(columns_def)});")
            return True
        except Exception as e:
            print(f"Error creating table: {e}")
            return False
    
    def insert_result(self, columns, values):
        """Insert a result row into the database"""
        if not self.conn:
            return False
            
        try:
            placeholders = ', '.join(['?'] * len(values))
            self.conn.execute(f"INSERT INTO results VALUES ({placeholders});", values)
            return True
        except Exception as e:
            print(f"Error inserting result: {e}")
            return False
    
    def query_results(self, sort_column="Score", descending=True):
        """Query results from the database, optionally sorted"""
        if not self.conn:
            return None
            
        try:
            # Check if the results table exists
            table_exists = self.conn.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'results'").fetchone()[0]
            if not table_exists:
                return None
                
            # Query with optional sorting
            direction = "DESC" if descending else "ASC"
            result = self.conn.execute(f'SELECT * FROM results ORDER BY "{sort_column}" {direction}').fetch_df()
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