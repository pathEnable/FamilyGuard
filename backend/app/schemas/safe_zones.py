from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import time

class SafeZoneBase(BaseModel):
    name: str
    latitude: float
    longitude: float
    radius_meters: float = 100.0
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    is_active: bool = True

class SafeZoneCreate(SafeZoneBase):
    pass

class SafeZoneUpdate(BaseModel):
    name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_meters: Optional[float] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    is_active: Optional[bool] = None

class SafeZoneResponse(SafeZoneBase):
    id: int
    profile_id: int

    model_config = ConfigDict(from_attributes=True)
