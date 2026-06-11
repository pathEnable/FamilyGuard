from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime

# Profile Schemas
class ProfileBase(BaseModel):
    name: str
    age: int
    avatar_url: Optional[str] = None

class ProfileCreate(ProfileBase):
    pin_code: Optional[str] = None

class Profile(ProfileBase):
    id: int
    parent_id: int
    is_locked: bool
    created_at: datetime

    class Config:
        from_attributes = True

# User Schemas
class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    profiles: List[Profile] = []

    class Config:
        from_attributes = True

class ActivityLogSchema(BaseModel):
    id: int
    profile_id: int
    profile_name: Optional[str] = None
    activity_type: str
    description: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str
