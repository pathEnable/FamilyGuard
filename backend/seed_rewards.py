import asyncio
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.user import Profile, Reward

async def seed_rewards():
    db = SessionLocal()
    try:
        profiles = db.query(Profile).all()
        for profile in profiles:
            existing_rewards = db.query(Reward).filter(Reward.profile_id == profile.id).count()
            if existing_rewards == 0:
                rewards = [
                    Reward(profile_id=profile.id, title="+30 min d'écran", description="30 minutes de temps d'écran supplémentaire", bonus_minutes=30, point_cost=100),
                    Reward(profile_id=profile.id, title="Soirée Film", description="Choisis le film ce soir", bonus_minutes=0, point_cost=300),
                    Reward(profile_id=profile.id, title="1h de Jeu Vidéo", description="1h de console supplémentaire", bonus_minutes=60, point_cost=200),
                    Reward(profile_id=profile.id, title="Joker Week-end", description="Pas de limites pendant 2h le week-end", bonus_minutes=120, point_cost=500),
                ]
                db.add_all(rewards)
        db.commit()
        print("Default rewards seeded successfully!")
    except Exception as e:
        db.rollback()
        print(f"Error seeding rewards: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(seed_rewards())
