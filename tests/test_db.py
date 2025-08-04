import os
import pytest
from db import mysql_connector, table_exists, admin

# Optional: load environment variables for DB connection, or set them aquí
os.environ["DB_HOST"] = "localhost"
os.environ["DB_USER"] = "root"
os.environ["DB_PASSWORD"] = "root"
os.environ["DB_NAME"] = "stomology_dep"

@pytest.fixture(scope="module")
def db_cursor():
    """Fixture to provide a cursor for tests."""
    db, cursor = mysql_connector()
    yield cursor
    cursor.close()
    db.close()

def test_table_exists(db_cursor):
    # Test if 'admin' table exists in the database
    assert table_exists(db_cursor, "admin") is True or False  # Adjust expected value depending on your DB state

def test_admin_data(db_cursor):
    # Test that the admin function returns a list (could be empty)
    admins = admin(db_cursor)
    assert isinstance(admins, list)

