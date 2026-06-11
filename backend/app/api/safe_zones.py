from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models.user import User, Profile, SafeZone
from app.schemas.safe_zones import SafeZoneCreate, SafeZoneResponse, SafeZoneUpdate
from app.api.deps import get_current_user

router = APIRouter()

def _get_profile_for_parent(profile_id: int, db: Session, current_user: User) -> Profile:
    profile = db.query(Profile).filter(Profile.id == profile_id).first()
    if not profile or profile.parent_id != current_user.id:
        raise HTTPException(status_code=404, detail="Profil non trouvé")
    return profile


@router.post("/{profile_id}/safe-zones", response_model=SafeZoneResponse)
def create_safe_zone(
    profile_id: int,
    zone_in: SafeZoneCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Créer une zone de sécurité (Geofencing) pour un profil."""
    profile = _get_profile_for_parent(profile_id, db, current_user)
    
    new_zone = SafeZone(
        profile_id=profile.id,
        name=zone_in.name,
        latitude=zone_in.latitude,
        longitude=zone_in.longitude,
        radius_meters=zone_in.radius_meters,
        start_time=zone_in.start_time,
        end_time=zone_in.end_time,
        is_active=zone_in.is_active,
    )
    db.add(new_zone)
    db.commit()
    db.refresh(new_zone)
    return new_zone


@router.get("/{profile_id}/safe-zones", response_model=List[SafeZoneResponse])
def get_safe_zones(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Liste toutes les zones de sécurité d'un profil."""
    profile = _get_profile_for_parent(profile_id, db, current_user)
    return profile.safe_zones


@router.put("/{profile_id}/safe-zones/{zone_id}", response_model=SafeZoneResponse)
def update_safe_zone(
    profile_id: int,
    zone_id: int,
    zone_in: SafeZoneUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mettre à jour une zone de sécurité."""
    _get_profile_for_parent(profile_id, db, current_user)
    
    zone = db.query(SafeZone).filter(SafeZone.id == zone_id, SafeZone.profile_id == profile_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone non trouvée")

    update_data = zone_in.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(zone, key, value)
        
    db.commit()
    db.refresh(zone)
    return zone


@router.delete("/{profile_id}/safe-zones/{zone_id}")
def delete_safe_zone(
    profile_id: int,
    zone_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Supprimer une zone de sécurité."""
    _get_profile_for_parent(profile_id, db, current_user)
    
    zone = db.query(SafeZone).filter(SafeZone.id == zone_id, SafeZone.profile_id == profile_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone non trouvée")
        
    db.delete(zone)
    db.commit()
    return {"detail": "Zone de sécurité supprimée"}
