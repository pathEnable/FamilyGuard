from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from app.core.database import get_db
from app.models.user import User, Profile, ActivityLog, ActivityType, AppUsage
from app.schemas.user import ProfileCreate, Profile as ProfileSchema
from app.api.deps import get_current_user
from app.core.security import pwd_context
from app.api.ws import manager
from pydantic import BaseModel
from datetime import date, timedelta

router = APIRouter()

@router.post("/", response_model=ProfileSchema)
def create_profile(
    profile_in: ProfileCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    # Check max profiles limit (e.g., 6)
    if len(current_user.profiles) >= 6:
        raise HTTPException(status_code=400, detail="Maximum number of profiles reached (6)")
        
    new_profile = Profile(
        parent_id=current_user.id,
        name=profile_in.name,
        age=profile_in.age,
        avatar_url=profile_in.avatar_url,
        pin_code=pwd_context.hash(profile_in.pin_code) if profile_in.pin_code else None
    )
    db.add(new_profile)
    db.commit()
    db.refresh(new_profile)
    return new_profile

@router.get("/", response_model=List[ProfileSchema])
def list_profiles(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return db.query(Profile).filter(Profile.parent_id == current_user.id).all()

@router.put("/{profile_id}", response_model=ProfileSchema)
def update_profile(profile_id: int, profile_in: ProfileCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    profile = db.query(Profile).filter(Profile.id == profile_id, Profile.parent_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    profile.name = profile_in.name
    profile.age = profile_in.age
    db.commit()
    db.refresh(profile)
    return profile

@router.delete("/{profile_id}")
def delete_profile(profile_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    profile = db.query(Profile).filter(Profile.id == profile_id, Profile.parent_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    db.delete(profile)
    db.commit()
    return {"status": "success", "message": "Profile deleted"}

from app.schemas.user import ActivityLogSchema
from app.models.user import ActivityLog

@router.get("/logs/all")
def get_all_logs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 50
):
    profile_ids = [p.id for p in current_user.profiles]
    if not profile_ids:
        return {"items": [], "total": 0, "skip": skip, "limit": limit}
        
    query = db.query(ActivityLog).filter(ActivityLog.profile_id.in_(profile_ids))
    total = query.count()
    logs = query.order_by(ActivityLog.created_at.desc()).offset(skip).limit(limit).all()
    
    profile_name_map = {p.id: p.name for p in current_user.profiles}
    
    result = []
    for log in logs:
        log_dict = {
            "id": log.id,
            "profile_id": log.profile_id,
            "profile_name": profile_name_map.get(log.profile_id, "Inconnu"),
            "activity_type": log.activity_type,
            "description": log.description,
            "created_at": log.created_at
        }
        result.append(log_dict)
    return {
        "items": result,
        "total": total,
        "skip": skip,
        "limit": limit
    }

@router.get("/{profile_id}/logs")
def get_profile_logs(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 50
):
    # Verify profile belongs to user
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    query = db.query(ActivityLog).filter(ActivityLog.profile_id == profile_id)
    total = query.count()
    logs = query.order_by(ActivityLog.created_at.desc()).offset(skip).limit(limit).all()
    
    result = []
    for log in logs:
        log_dict = {
            "id": log.id,
            "profile_id": log.profile_id,
            "profile_name": profile.name,
            "activity_type": log.activity_type,
            "description": log.description,
            "created_at": log.created_at
        }
        result.append(log_dict)
    return {
        "items": result,
        "total": total,
        "skip": skip,
        "limit": limit
    }


# ──────────────────────────────────────────────────────────
# PIN CODE MANAGEMENT
# ──────────────────────────────────────────────────────────

from pydantic import BaseModel

class PinSet(BaseModel):
    pin: str  # 4-6 digit PIN

class PinVerify(BaseModel):
    pin: str


@router.put("/{profile_id}/pin")
def set_pin(
    profile_id: int,
    pin_data: PinSet,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Set or update the PIN code for a child profile (parent only)."""
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    pin = pin_data.pin.strip()
    if not pin.isdigit() or len(pin) < 4 or len(pin) > 6:
        raise HTTPException(status_code=400, detail="Le PIN doit contenir 4 à 6 chiffres")

    profile.pin_code = pwd_context.hash(pin)
    db.commit()
    return {"status": "success", "message": "PIN mis à jour"}


@router.post("/{profile_id}/verify-pin")
def verify_pin(
    profile_id: int,
    pin_data: PinVerify,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Verify PIN code to exit the child interface."""
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    if not profile.pin_code:
        # No PIN set — allow exit
        return {"valid": True, "message": "Aucun PIN configuré"}

    if pwd_context.verify(pin_data.pin.strip(), profile.pin_code):
        return {"valid": True, "message": "PIN correct"}
    else:
        raise HTTPException(status_code=403, detail="PIN incorrect")


@router.get("/{profile_id}/has-pin")
def has_pin(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Check if a profile has a PIN configured."""
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return {"has_pin": bool(profile.pin_code)}


# ──────────────────────────────────────────────────────────
# DAILY USAGE STATS (for web dashboard)
# ──────────────────────────────────────────────────────────

from app.models.user import AppUsage
from datetime import date

@router.get("/{profile_id}/daily-usage")
def get_daily_usage(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get today's usage stats for the web dashboard."""
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    today = date.today()
    usage = db.query(AppUsage).filter(
        AppUsage.profile_id == profile_id,
        AppUsage.date == today
    ).first()

    minutes_used = usage.minutes_used if usage else 0
    
    alert_count = db.query(ActivityLog).filter(
        ActivityLog.profile_id == profile_id,
        func.date(ActivityLog.created_at) == today
    ).count()

    return {
        "profile_id": profile_id,
        "date": today.isoformat(),
        "minutes_used": minutes_used,
        "formatted": f"{minutes_used // 60}h {minutes_used % 60:02d}m",
        "alert_count": alert_count
    }

# ──────────────────────────────────────────────────────────
# INSTANT LOCK & WEEKLY USAGE
# ──────────────────────────────────────────────────────────

class LockToggle(BaseModel):
    is_locked: bool

@router.put("/{profile_id}/lock")
async def toggle_lock(
    profile_id: int,
    lock_data: LockToggle,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Toggle instant lock for a device."""
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    profile.is_locked = lock_data.is_locked
    db.commit()
    
    # Broadcast to all child devices of this parent
    await manager.broadcast_to_parent(current_user.id, {
        "type": "rules_updated",
        "profile_id": profile.id,
        "action": "lock_toggled",
        "is_locked": profile.is_locked
    })
    
    return {"status": "success", "is_locked": profile.is_locked}

from datetime import timedelta

@router.get("/{profile_id}/weekly-usage")
def get_weekly_usage(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get usage stats for the last 7 days."""
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    today = date.today()
    start_date = today - timedelta(days=6)

    usages = db.query(AppUsage).filter(
        AppUsage.profile_id == profile_id,
        AppUsage.date >= start_date,
        AppUsage.date <= today
    ).all()

    usage_map = {u.date: u.minutes_used for u in usages}
    
    result = []
    # French day abbreviations
    day_names = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
    
    for i in range(7):
        current_date = start_date + timedelta(days=i)
        day_str = day_names[current_date.weekday()]
        
        minutes = usage_map.get(current_date, 0)
        result.append({
            "date": current_date.isoformat(),
            "day": day_str,
            "minutes": minutes
        })
    return result

# ──────────────────────────────────────────────────────────
# CYBERBULLYING ALERT
# ──────────────────────────────────────────────────────────

class HarassmentAlert(BaseModel):
    app_package: str

from app.services.fcm_service import send_push_notification

@router.post("/{profile_id}/harassment-alert")
def trigger_harassment_alert(
    profile_id: int,
    alert_data: HarassmentAlert,
    db: Session = Depends(get_db)
):
    """Triggered by child device when bad words are detected in notifications."""
    profile = db.query(Profile).filter(Profile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    parent = profile.parent

    # Log the activity
    log = ActivityLog(
        profile_id=profile_id,
        activity_type=ActivityType.CYBERBULLYING_DETECTED,
        description=f"Harcèlement potentiel détecté dans l'app: {alert_data.app_package}"
    )
    db.add(log)
    db.commit()

    # Send FCM push to parent
    if parent.fcm_token:
        send_push_notification(
            token=parent.fcm_token,
            title="⚠️ Alerte Cyberharcèlement",
            body=f"Des mots sensibles ont été détectés sur l'appareil de {profile.name} (App: {alert_data.app_package}).",
            data={"type": "HARASSMENT", "profile_id": str(profile_id)}
        )

    return {"status": "success", "message": "Harassment alert processed"}

