import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import pytest
from db import mysql_connector, table_exists, admin

# Set environment variables needed for the database connection
os.environ["DB_HOST"] = "localhost"
os.environ["DB_USER"] = "root"
os.environ["DB_PASSWORD"] = "root"
os.environ["DB_NAME"] = "stomology_dep"

@pytest.fixture(scope="module")
def db_cursor():
    """Fixture to provide a database cursor and close it after tests."""
    db, cursor = mysql_connector()
    yield cursor
    cursor.close()
    db.close()

def test_table_exists(db_cursor):
    """Test to verify if the 'admin' table exists."""
    assert table_exists(db_cursor, "admin") is True

def test_admin_data(db_cursor):
    """Test to verify that the admin function returns a list."""
    admins = admin(db_cursor)
    assert isinstance(admins, list)
