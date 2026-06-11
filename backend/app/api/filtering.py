from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from pydantic import BaseModel
import os

# Ensure the bloom generator creates the file at startup
from app.services.bloom_generator import bloom_manager

router = APIRouter()

@router.get("/filter.bin")
def download_bloom_filter():
    """
    Endpoint for the child's mobile app to download the latest Bloom Filter.
    This allows 100% local, zero-latency privacy-preserving domain filtering.
    """
    filter_path = bloom_manager.filter_file
    if not os.path.exists(filter_path):
        raise HTTPException(status_code=404, detail="Filter not found")
        
    return FileResponse(
        path=filter_path, 
        media_type="application/octet-stream", 
        filename="filter.bin"
    )

class FilterLogRequest(BaseModel):
    profile_id: int
    url: str
    reason: str

@router.post("/log")
async def log_blocked_url(
    request: FilterLogRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.models.user import Profile, ActivityLog, ActivityType
    from app.api.ws import manager

    # Verify profile belongs to current user
    profile = db.query(Profile).filter(
        Profile.id == request.profile_id,
        Profile.parent_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    log = ActivityLog(
        profile_id=profile.id,
        activity_type=ActivityType.WEB_BLOCKED,
        description=f"Accès bloqué : {request.url} ({request.reason})"
    )
    db.add(log)
    db.commit()
    db.refresh(log)

    # Broadcast to parent
    message = {
        "type": "WEB_BLOCKED",
        "profile_id": profile.id,
        "profile_name": profile.name,
        "message": f"Navigation bloquée pour {profile.name} : {request.url}",
        "timestamp": log.created_at.isoformat()
    }
    await manager.broadcast_to_parent(current_user.id, message)

    return {"status": "success"}

# The old POST /check endpoint can still be kept for testing/debugging
class URLCheckRequest(BaseModel):
    url: str

class URLCheckResponse(BaseModel):
    url: str
    is_blocked: bool
    reason: str | None = None

@router.post("/check", response_model=URLCheckResponse)
def check_url(request: URLCheckRequest):
    is_blocked = bloom_manager.is_url_blocked(request.url)
    if is_blocked:
        return URLCheckResponse(url=request.url, is_blocked=True, reason="Category blocked (Bloom Filter)")
    return URLCheckResponse(url=request.url, is_blocked=False)
