import os
import pytest
from db import mysql_connector, table_exists, admin

# Configura las variables de entorno necesarias para la conexión
os.environ["DB_HOST"] = "localhost"
os.environ["DB_USER"] = "root"
os.environ["DB_PASSWORD"] = "root"
os.environ["DB_NAME"] = "stomology_dep"

@pytest.fixture(scope="module")
def db_cursor():
    """Fixture para obtener un cursor de la base de datos y cerrarlo después."""
    db, cursor = mysql_connector()
    yield cursor
    cursor.close()
    db.close()

def test_table_exists(db_cursor):
    """Test que verifica si la tabla 'admin' existe."""
    assert table_exists(db_cursor, "admin") is True

def test_admin_data(db_cursor):
    """Test que verifica que la función admin devuelve una lista."""
    admins = admin(db_cursor)
    assert isinstance(admins, list)
