"""
Script to add missing values to the PostgreSQL 'ruletype' enum.
PostgreSQL enums are static - new values must be added with ALTER TYPE.
Run this once against your Neon database.
"""
import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("ERROR: DATABASE_URL not set in environment")
    exit(1)

engine = create_engine(DATABASE_URL)

# The enum values we need in the database
required_values = ["DAILY_LIMIT", "BEDTIME_BLOCK", "EXAM_MODE", "APP_BLOCK"]

with engine.connect() as conn:
    # First, check which values already exist
    result = conn.execute(text("""
        SELECT enumlabel FROM pg_enum 
        WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'ruletype')
    """))
    existing_values = [row[0] for row in result]
    print(f"Existing enum values: {existing_values}")

    for value in required_values:
        if value not in existing_values:
            print(f"  Adding '{value}' to ruletype enum...")
            conn.execute(text(f"ALTER TYPE ruletype ADD VALUE IF NOT EXISTS '{value}'"))
            print(f"  [OK] Added '{value}'")
        else:
            print(f"  [OK] '{value}' already exists")
    
    conn.commit()

    # Also check activitytype enum
    result = conn.execute(text("""
        SELECT enumlabel FROM pg_enum 
        WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'activitytype')
    """))
    existing_activity = [row[0] for row in result]
    print(f"\nExisting activitytype values: {existing_activity}")

    activity_values = ["SOS_TRIGGERED", "WEB_BLOCKED", "TIME_LIMIT_REACHED", "GEOFENCE_ALERT", "CYBERBULLYING_DETECTED"]
    for value in activity_values:
        if value not in existing_activity:
            print(f"  Adding '{value}' to activitytype enum...")
            conn.execute(text(f"ALTER TYPE activitytype ADD VALUE IF NOT EXISTS '{value}'"))
            print(f"  [OK] Added '{value}'")
        else:
            print(f"  [OK] '{value}' already exists")

    conn.commit()

print("\n[DONE] Enum migration complete!")
