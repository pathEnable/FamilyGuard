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

class WebFilterRuleCreate(BaseModel):
    url_pattern: str
    rule_type: str

class WebFilterRuleResponse(BaseModel):
    id: int
    url_pattern: str
    rule_type: str # Or use FilterRuleType, but wait! We can use from app.models.user import FilterRuleType but it creates circular imports if placed incorrectly.
    # To fix string serialization safely in Pydantic v1 and v2, we can just use Config
    
    class Config:
        from_attributes = True
        use_enum_values = True

class WebFilterSettingsResponse(BaseModel):
    strict_mode: bool = False
    rules: list[WebFilterRuleResponse]

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

@router.get("/profiles/{profile_id}/rules", response_model=WebFilterSettingsResponse)
def get_web_filters(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.models.user import Profile, WebFilterRule
    profile = db.query(Profile).filter(
        Profile.id == profile_id,
        Profile.parent_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    return WebFilterSettingsResponse(
        strict_mode=profile.strict_web_filter or False,
        rules=profile.web_filter_rules
    )

@router.post("/profiles/{profile_id}/rules", response_model=WebFilterRuleResponse)
async def add_web_filter_rule(
    profile_id: int,
    request: WebFilterRuleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.models.user import Profile, WebFilterRule, FilterRuleType
    from app.api.ws import manager
    
    profile = db.query(Profile).filter(
        Profile.id == profile_id,
        Profile.parent_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    try:
        rule_type = FilterRuleType(request.rule_type)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid rule_type. Must be WHITELIST or BLACKLIST.")
        
    rule = WebFilterRule(
        profile_id=profile_id,
        url_pattern=request.url_pattern,
        rule_type=rule_type
    )
    db.add(rule)
    db.commit()
    db.refresh(rule)
    
    await manager.broadcast_rules_updated(current_user.id, profile.id)
    return rule

@router.delete("/profiles/{profile_id}/rules/{rule_id}")
async def delete_web_filter_rule(
    profile_id: int,
    rule_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.models.user import Profile, WebFilterRule
    from app.api.ws import manager
    
    profile = db.query(Profile).filter(
        Profile.id == profile_id,
        Profile.parent_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    rule = db.query(WebFilterRule).filter(
        WebFilterRule.id == rule_id,
        WebFilterRule.profile_id == profile.id
    ).first()
    
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")
        
    db.delete(rule)
    db.commit()
    
    await manager.broadcast_rules_updated(current_user.id, profile.id)
    return {"status": "success"}

from fastapi import Body

@router.put("/profiles/{profile_id}/strict-mode")
async def toggle_strict_mode(
    profile_id: int,
    strict_mode: bool = Body(..., embed=True),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.models.user import Profile
    from app.api.ws import manager
    
    profile = db.query(Profile).filter(
        Profile.id == profile_id,
        Profile.parent_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    profile.strict_web_filter = strict_mode
    db.commit()
    
    await manager.broadcast_rules_updated(current_user.id, profile.id)
    return {"status": "success", "strict_mode": strict_mode}

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
