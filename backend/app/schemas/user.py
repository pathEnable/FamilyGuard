from pydantic import BaseModel, EmailStr, field_validator
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
    formatted_usage: Optional[str] = "0h 00m"
    alert_count: Optional[int] = 0

    class Config:
        from_attributes = True

# User Schemas
class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str

    @field_validator('password')
    @classmethod
    def validate_password_strength(cls, v):
        if len(v) < 8:
            raise ValueError('Le mot de passe doit faire au moins 8 caractères')
        if not any(char.isdigit() for char in v):
            raise ValueError('Le mot de passe doit contenir au moins un chiffre')
        if not any(char.isupper() for char in v):
            raise ValueError('Le mot de passe doit contenir au moins une majuscule')
        if not any(char in "!@#$%^&*()_+-=[]{}|;:,.<>?" for char in v):
            raise ValueError('Le mot de passe doit contenir au moins un caractère spécial')
        return v

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

    @field_validator('new_password')
    @classmethod
    def validate_password_strength(cls, v):
        if len(v) < 8:
            raise ValueError('Le mot de passe doit faire au moins 8 caractères')
        if not any(char.isdigit() for char in v):
            raise ValueError('Le mot de passe doit contenir au moins un chiffre')
        if not any(char.isupper() for char in v):
            raise ValueError('Le mot de passe doit contenir au moins une majuscule')
        if not any(char in "!@#$%^&*()_+-=[]{}|;:,.<>?" for char in v):
            raise ValueError('Le mot de passe doit contenir au moins un caractère spécial')
        return v
