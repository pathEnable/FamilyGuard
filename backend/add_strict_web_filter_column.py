import sqlite3

def add_strict_web_filter_column():
    conn = sqlite3.connect('safechild.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute("ALTER TABLE profiles ADD COLUMN strict_web_filter BOOLEAN DEFAULT 0;")
        print("Successfully added strict_web_filter column to profiles table.")
        conn.commit()
    except sqlite3.OperationalError as e:
        if "duplicate column name" in str(e):
            print("Column strict_web_filter already exists.")
        else:
            print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    add_strict_web_filter_column()
