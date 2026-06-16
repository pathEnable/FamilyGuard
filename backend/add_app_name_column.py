import sqlite3

def add_app_name_column():
    conn = sqlite3.connect('safechild.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute("ALTER TABLE app_usages ADD COLUMN app_name VARCHAR;")
        print("Successfully added app_name column to app_usages table.")
        conn.commit()
    except sqlite3.OperationalError as e:
        if "duplicate column name" in str(e):
            print("Column app_name already exists.")
        else:
            print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    add_app_name_column()
