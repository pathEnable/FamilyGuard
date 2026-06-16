import sys
import os

# Add backend directory to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.user import QuizQuestion
from app.api.quiz_data import QUIZ_QUESTIONS

def seed_quizzes():
    db = SessionLocal()
    try:
        # Check if already seeded
        existing_count = db.query(QuizQuestion).filter(QuizQuestion.profile_id == None).count()
        if existing_count == 0:
            for q in QUIZ_QUESTIONS:
                question = QuizQuestion(
                    profile_id=None,
                    category=q["category"],
                    question=q["question"],
                    options=q["options"],
                    correct_index=q["correct_index"],
                    points=q["points"]
                )
                db.add(question)
            db.commit()
            print(f"Successfully seeded {len(QUIZ_QUESTIONS)} questions.")
        else:
            print("Questions already seeded.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_quizzes()
