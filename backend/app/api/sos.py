from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.user import User, Profile, ActivityLog, ActivityType
from app.api.deps import get_current_user
from app.api.ws import manager
from app.core import firebase

router = APIRouter()

@router.post("/{profile_id}/sos")
async def trigger_sos(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Verify profile belongs to current user
    profile = db.query(Profile).filter(
        Profile.id == profile_id,
        Profile.parent_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Create Activity Log
    log = ActivityLog(
        profile_id=profile.id,
        activity_type=ActivityType.SOS_TRIGGERED,
        description="L'enfant a déclenché une alerte SOS !"
    )
    db.add(log)
    db.commit()
    db.refresh(log)

    # Broadcast via WebSocket to the parent
    message = {
        "type": "SOS_TRIGGERED",
        "profile_id": profile.id,
        "profile_name": profile.name,
        "message": f"🚨 SOS déclenché par {profile.name} !",
        "timestamp": log.created_at.isoformat()
    }
    await manager.broadcast_to_parent(current_user.id, message)
    
    # Send FCM Push Notification
    if current_user.fcm_token:
        firebase.send_push_notification(
            token=current_user.fcm_token,
            title="ALERTE SOS",
            body=f"{profile.name} a besoin d'aide immédiate !",
            data={"type": "SOS", "profile_id": str(profile.id)}
        )

    return {"status": "success", "message": "SOS triggered"}
