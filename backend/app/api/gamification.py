from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, date, timedelta
from pydantic import BaseModel

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User, Profile, PointTransaction, Badge, Reward, BadgeType, Quest, QuestStatus

router = APIRouter()

# ── Schemas ──

class PointTransactionSchema(BaseModel):
    id: int
    amount: int
    reason: str
    created_at: datetime
    class Config: from_attributes = True

class BadgeSchema(BaseModel):
    id: int
    badge_type: str
    name: str
    icon_emoji: str
    unlocked_at: datetime
    class Config: from_attributes = True

class RewardSchema(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    bonus_minutes: int
    point_cost: int
    is_claimed: bool
    created_at: datetime
    claimed_at: Optional[datetime] = None
    class Config: from_attributes = True

class QuestSchema(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    points_reward: int
    status: str
    created_at: datetime
    completed_at: Optional[datetime] = None
    class Config: from_attributes = True

class QuestCreate(BaseModel):
    title: str
    description: Optional[str] = None
    points_reward: int = 10

class GamificationSummarySchema(BaseModel):
    total_points: int
    current_streak: int
    best_streak: int
    avatar_level: int
    recent_badges: List[BadgeSchema]


class RewardCreate(BaseModel):
    title: str
    description: Optional[str] = None
    bonus_minutes: int
    point_cost: int


# ── Logic Helpers ──

def add_points(db: Session, profile: Profile, amount: int, reason: str):
    profile.total_points += amount
    
    # Check level up (e.g., Level 1: 0-99, Level 2: 100-249, Level 3: 250-499, Level 4: 500-999, Level 5: 1000+)
    if profile.total_points >= 1000:
        profile.avatar_level = 5
    elif profile.total_points >= 500:
        profile.avatar_level = 4
    elif profile.total_points >= 250:
        profile.avatar_level = 3
    elif profile.total_points >= 100:
        profile.avatar_level = 2
    else:
        profile.avatar_level = 1

    transaction = PointTransaction(
        profile_id=profile.id,
        amount=amount,
        reason=reason
    )
    db.add(transaction)
    db.commit()

def award_badge(db: Session, profile: Profile, badge_type: BadgeType, name: str, emoji: str, points: int):
    # Check if already has this badge
    existing = db.query(Badge).filter(Badge.profile_id == profile.id, Badge.badge_type == badge_type).first()
    if not existing:
        badge = Badge(
            profile_id=profile.id,
            badge_type=badge_type,
            name=name,
            icon_emoji=emoji
        )
        db.add(badge)
        add_points(db, profile, points, f"Badge débloqué : {name}")


# ── Endpoints ──

@router.get("/{profile_id}", response_model=GamificationSummarySchema)
def get_gamification_summary(
    profile_id: int, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    badges = db.query(Badge).filter(Badge.profile_id == profile_id).order_by(Badge.unlocked_at.desc()).limit(3).all()
    
    return {
        "total_points": profile.total_points,
        "current_streak": profile.current_streak,
        "best_streak": profile.best_streak,
        "avatar_level": profile.avatar_level,
        "recent_badges": badges
    }

@router.post("/{profile_id}/reward", response_model=RewardSchema)
def create_reward(
    profile_id: int,
    reward_in: RewardCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    new_reward = Reward(
        profile_id=profile_id,
        title=reward_in.title,
        description=reward_in.description,
        bonus_minutes=reward_in.bonus_minutes,
        point_cost=reward_in.point_cost
    )
    db.add(new_reward)
    db.commit()
    db.refresh(new_reward)
    return new_reward

@router.get("/{profile_id}/rewards", response_model=List[RewardSchema])
def list_rewards(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    return db.query(Reward).filter(Reward.profile_id == profile_id).order_by(Reward.is_claimed.asc(), Reward.created_at.desc()).all()


@router.post("/{profile_id}/rewards/{reward_id}/claim")
def claim_reward(
    profile_id: int,
    reward_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    reward = db.query(Reward).filter(Reward.id == reward_id, Reward.profile_id == profile_id).first()
    if not reward:
        raise HTTPException(status_code=404, detail="Reward not found")
        
    if reward.is_claimed:
        raise HTTPException(status_code=400, detail="Récompense déjà utilisée")
        
    if profile.total_points < reward.point_cost:
        raise HTTPException(status_code=400, detail="Points insuffisants")
        
    reward.is_claimed = True
    reward.claimed_at = func.now()
    
    add_points(db, profile, -reward.point_cost, f"Achat récompense : {reward.title}")
    
    # Note: the bonus minutes should technically be applied to today's rule limits,
    # or added to a 'bonus_pool' in Profile. For now, it's claimed successfully.
    
    db.commit()
    return {"status": "success", "message": "Récompense réclamée avec succès !"}

@router.get("/{profile_id}/points-history", response_model=List[PointTransactionSchema])
def get_points_history(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    return db.query(PointTransaction).filter(PointTransaction.profile_id == profile_id).order_by(PointTransaction.created_at.desc()).all()


@router.post("/{profile_id}/check-streak")
def update_streak(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Called daily (e.g. via background job) or lazily to verify if the child 
    respected limits yesterday.
    For demonstration, this endpoint artificially increases the streak by 1.
    """
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    profile.current_streak += 1
    if profile.current_streak > profile.best_streak:
        profile.best_streak = profile.current_streak
        
    add_points(db, profile, 10, "Journée validée !")
    
    if profile.current_streak == 3:
        award_badge(db, profile, BadgeType.BRONZE_3D, "Série Bronze (3j)", "🥉", 20)
    elif profile.current_streak == 7:
        award_badge(db, profile, BadgeType.SILVER_7D, "Série Argent (7j)", "🥈", 50)
    elif profile.current_streak == 30:
        award_badge(db, profile, BadgeType.GOLD_30D, "Série Or (30j)", "🥇", 100)

    db.commit()
    return {"status": "success", "current_streak": profile.current_streak}


@router.post("/{profile_id}/disconnect-early")
def disconnect_early(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Called by the child app when they intentionally disconnect before their 
    screen time is fully consumed.
    Awards 1 point per 5 minutes saved, then locks the device for the rest of the day.
    """
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    if profile.is_locked:
        raise HTTPException(status_code=400, detail="Appareil déjà verrouillé")

    # Get today's usage and daily limit to calculate remaining time
    today = date.today()
    from app.models.user import AppUsage, TimeRule, RuleType
    
    usage = db.query(AppUsage).filter(
        AppUsage.profile_id == profile.id,
        AppUsage.date == today
    ).first()
    minutes_used = usage.minutes_used if usage else 0

    daily_rule = db.query(TimeRule).filter(
        TimeRule.profile_id == profile.id,
        TimeRule.rule_type == RuleType.DAILY_LIMIT,
        TimeRule.is_active == True,
    ).first()

    if not daily_rule or daily_rule.max_minutes_per_day is None:
        raise HTTPException(status_code=400, detail="Aucune limite quotidienne définie")

    minutes_remaining = max(0, daily_rule.max_minutes_per_day - minutes_used)

    if minutes_remaining < 5:
        raise HTTPException(status_code=400, detail="Temps restant insuffisant pour gagner des points")

    # Award 1 point per 5 minutes saved
    points_earned = minutes_remaining // 5
    
    add_points(db, profile, points_earned, f"Déconnexion anticipée ({minutes_remaining}min économisées)")
    
    # Lock the profile to validate the disconnection
    profile.is_locked = True
    db.commit()

    return {
        "status": "success", 
        "points_earned": points_earned,
        "message": f"Vous avez gagné {points_earned} points de confiance !"
    }

# ──────────────────────────────────────────────────────────
# QUESTS
# ──────────────────────────────────────────────────────────

@router.get("/{profile_id}/quests", response_model=List[QuestSchema])
def get_quests(
    profile_id: int,
    db: Session = Depends(get_db),
    # Both parent and child can view quests, skipping auth restriction for child token for simplicity
):
    profile = db.query(Profile).filter(Profile.id == profile_id).first()
    if not profile: raise HTTPException(status_code=404, detail="Profil introuvable")

    return db.query(Quest).filter(Quest.profile_id == profile.id).order_by(Quest.created_at.desc()).all()


@router.post("/{profile_id}/quests", response_model=QuestSchema)
def create_quest(
    profile_id: int,
    quest_data: QuestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = _get_profile_for_parent(profile_id, db, current_user)
    
    quest = Quest(
        profile_id=profile.id,
        title=quest_data.title,
        description=quest_data.description,
        points_reward=quest_data.points_reward,
        status=QuestStatus.PENDING
    )
    db.add(quest)
    db.commit()
    db.refresh(quest)
    return quest


@router.put("/quests/{quest_id}/complete")
def complete_quest(
    quest_id: int,
    db: Session = Depends(get_db),
):
    # L'enfant marque la quête comme terminée (en attente de validation)
    quest = db.query(Quest).filter(Quest.id == quest_id).first()
    if not quest: raise HTTPException(status_code=404, detail="Quête introuvable")

    if quest.status != QuestStatus.PENDING:
        raise HTTPException(status_code=400, detail="Cette quête ne peut pas être terminée")

    quest.status = QuestStatus.COMPLETED_BY_CHILD
    db.commit()
    return {"message": "Quête marquée comme terminée, en attente du parent."}


@router.put("/quests/{quest_id}/validate")
def validate_quest(
    quest_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Le parent valide la quête et l'enfant reçoit les points
    quest = db.query(Quest).filter(Quest.id == quest_id).first()
    if not quest: raise HTTPException(status_code=404, detail="Quête introuvable")

    # On vérifie que le parent possède bien le profil
    _get_profile_for_parent(quest.profile_id, db, current_user)

    if quest.status != QuestStatus.COMPLETED_BY_CHILD:
        raise HTTPException(status_code=400, detail="La quête n'est pas en attente de validation")

    quest.status = QuestStatus.VALIDATED
    quest.completed_at = datetime.now()
    
    # Ajouter les points
    tx = PointTransaction(
        profile_id=quest.profile_id,
        amount=quest.points_reward,
        reason=f"Quête validée: {quest.title}"
    )
    db.add(tx)
    db.commit()

    return {"message": f"Quête validée, +{quest.points_reward} points accordés !"}
