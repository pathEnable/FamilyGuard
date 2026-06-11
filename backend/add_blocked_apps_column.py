from app.core.database import engine
from sqlalchemy import text

conn = engine.connect()
conn.execute(text("ALTER TABLE time_rules ADD COLUMN IF NOT EXISTS blocked_apps JSON"))
conn.commit()
conn.close()
print("Column 'blocked_apps' added successfully to time_rules table.")
