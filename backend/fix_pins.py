import sys
import os

# Add the backend directory to python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal
from app.models.user import Profile
from app.core.security import pwd_context

def fix():
    db = SessionLocal()
    try:
        profiles = db.query(Profile).filter(Profile.pin_code != None).all()
        count = 0
        for p in profiles:
            # If it's already a bcrypt hash, it starts with $2b$
            if not p.pin_code.startswith("$2b$"):
                print(f"Hashing PIN for profile {p.id}")
                p.pin_code = pwd_context.hash(p.pin_code)
                count += 1
        db.commit()
        print(f"Hashed {count} plaintext PINs.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    fix()
