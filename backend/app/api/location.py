import math
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List

from app.core.database import get_db
from app.models.user import User, Profile, SafeZone, ActivityLog, ActivityType
from app.api.deps import get_current_user
from app.core import firebase

router = APIRouter()

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float

def get_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great circle distance between two points on the earth (specified in decimal degrees)"""
    # Convert decimal degrees to radians
    lon1, lat1, lon2, lat2 = map(math.radians, [lon1, lat1, lon2, lat2])

    # Haversine formula
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    r = 6371000 # Radius of earth in meters
    return c * r

@router.post("/{profile_id}/location")
def update_location(
    profile_id: int,
    location: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Called by the child app periodically.
    Checks if the child is outside any active SafeZone.
    """
    profile = db.query(Profile).filter(Profile.id == profile_id).first()
    if not profile or profile.parent_id != current_user.id:
        raise HTTPException(status_code=404, detail="Profil non trouvé")

    now = datetime.now().time()
    
    # Check all active safe zones for this profile
    safe_zones = db.query(SafeZone).filter(SafeZone.profile_id == profile.id, SafeZone.is_active == True).all()
    
    for zone in safe_zones:
        # Check if the zone is currently active based on time
        is_time_active = True
        if zone.start_time and zone.end_time:
            if zone.start_time > zone.end_time:
                # Overnight
                is_time_active = now >= zone.start_time or now <= zone.end_time
            else:
                is_time_active = zone.start_time <= now <= zone.end_time
                
        if is_time_active:
            distance = get_distance(location.latitude, location.longitude, zone.latitude, zone.longitude)
            if distance > zone.radius_meters:
                # Log the activity
                log = ActivityLog(
                    profile_id=profile.id,
                    activity_type=ActivityType.GEOFENCE_ALERT,
                    description=f"Hors de la zone '{zone.name}' (Distance: {int(distance)}m)"
                )
                db.add(log)
                db.commit()
                
                # Send Push Notification
                if current_user.fcm_token:
                    firebase.send_push_notification(
                        token=current_user.fcm_token,
                        title="Alerte Geofencing 📍",
                        body=f"{profile.name} est sorti(e) de la zone '{zone.name}'.",
                        data={"type": "GEOFENCE_ALERT", "profile_id": str(profile.id), "zone_name": zone.name}
                    )
                
                # Just trigger once per update to avoid spamming if outside multiple zones
                break

    return {"status": "ok"}


class GeofenceAlert(BaseModel):
    zone_name: str
    transition_type: str  # "EXIT" or "ENTER"


@router.post("/{profile_id}/geofence-alert")
def geofence_alert(
    profile_id: int,
    alert: GeofenceAlert,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Called by the native Android GeofencingClient (via BroadcastReceiver)
    when the child exits or enters a SafeZone.
    This replaces continuous GPS polling with event-driven alerts,
    drastically reducing battery consumption.
    """
    profile = db.query(Profile).filter(Profile.id == profile_id).first()
    if not profile or profile.parent_id != current_user.id:
        raise HTTPException(status_code=404, detail="Profil non trouvé")

    if alert.transition_type == "EXIT":
        log = ActivityLog(
            profile_id=profile.id,
            activity_type=ActivityType.GEOFENCE_ALERT,
            description=f"Sorti(e) de la zone '{alert.zone_name}' (détection native)"
        )
        db.add(log)
        db.commit()

        # Send Push Notification to parent
        if current_user.fcm_token:
            firebase.send_push_notification(
                token=current_user.fcm_token,
                title="Alerte Geofencing 📍",
                body=f"{profile.name} est sorti(e) de la zone '{alert.zone_name}'.",
                data={
                    "type": "GEOFENCE_ALERT",
                    "profile_id": str(profile.id),
                    "zone_name": alert.zone_name,
                }
            )

    return {"status": "alert_processed", "transition": alert.transition_type}
