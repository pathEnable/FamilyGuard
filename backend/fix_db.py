import sys
import os

# Add the backend directory to python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal
from app.models.user import Profile

def fix():
    db = SessionLocal()
    try:
        profiles = db.query(Profile).filter(Profile.is_locked == None).all()
        count = 0
        for p in profiles:
            p.is_locked = False
            count += 1
        db.commit()
        print(f"Fixed {count} profiles where is_locked was NULL.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    fix()
