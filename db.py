import os
import mysql.connector

# Connecting with Database
def mysql_connector():
    mydb = mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        passwd=os.getenv("DB_PASSWORD", "root"),
        database=os.getenv("DB_NAME", "stomology_dep"),
    )

    # Initialize our cursor
    mycursor = mydb.cursor(buffered=True)
    return mydb, mycursor

"""Retrieve Database Tables"""

def admin(mycursor) :
    'Retrieve all admin data'
    mycursor.execute("SELECT * FROM admin")
    admin_table = mycursor.fetchall()

    return admin_table

def site_information(mycursor) :
    'Retrieve site information data'
    mycursor.execute("SELECT * FROM site_information")
    site_info_table = mycursor.fetchone()
    
    return site_info_table

def slider(mycursor) :
    'Retrieve slider data'
    mycursor.execute("SELECT * FROM slider")
    slider_table = mycursor.fetchall()
    
    return slider_table

def doctors(mycursor) :
    'Retrieve all doctors data'
    mycursor.execute("SELECT * FROM doctors")
    doctors_table = mycursor.fetchall()
    
    return doctors_table

def treatments(mycursor) :
    'Retrieve all treatments data'
    mycursor.execute("SELECT * FROM treatments")
    treatments_table = mycursor.fetchall()
    
    return treatments_table

def appointments(mycursor) :
    'Retrieve all appointments data'
    mycursor.execute("SELECT * FROM appointments")
    appointments_table = mycursor.fetchall()

    return appointments_table

def users(mycursor) :
    'Retrieve all users data'
    mycursor.execute("SELECT * FROM users")
    users_table = mycursor.fetchall()

    return users_table

def rates(mycursor) :
    'Retrieve all rates data'
    mycursor.execute("SELECT * FROM rates limit 10")
    rates_table = mycursor.fetchall()
    
    return rates_table

def retrive_tables(mycursor) :
    tables = dict()

    tables["admin"] = admin(mycursor)
    tables["site_information"] = site_information(mycursor)
    tables["slider"] = slider(mycursor)
    tables["doctors"] = doctors(mycursor)
    tables["treatments"] = treatments(mycursor)
    tables["appointments"] = appointments(mycursor)
    tables["users"] = users(mycursor)
    tables["rates"] = rates(mycursor)

    return tables


def table_exists(mycursor, table_name):
    query = """
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = %s AND table_name = %s
        LIMIT 1
    """
    database = os.getenv("DB_NAME", "stomology_dep")
    mycursor.execute(query, (database, table_name))
    return mycursor.fetchone()[0] == 1

def execute_sql_file(mydb, mycursor, sql_file_path):
    with open(sql_file_path, 'r') as file:
        sql_commands = file.read().split(';')
        for command in sql_commands:
            if command.strip():
                mycursor.execute(command)
    mydb.commit()

def init_database():
    mydb, mycursor = mysql_connector()
    if not table_exists(mycursor, 'admin'):
        print("Table 'admin' does not exist. Executing SQL script...")
        execute_sql_file(mydb, mycursor, "SQL/stomology_dep.sql")
        print("Database initialized.")
    else:
        print("The 'admin' table already exists. No initialization is required.")
    mycursor.close()
    mydb.close()
