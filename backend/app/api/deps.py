from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session
from app.core.config import settings
from app.core.database import get_db
from app.models import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")

def get_current_user(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
        
    return user

from app.models import Profile

def get_current_profile(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)) -> Profile:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate child credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        sub: str = payload.get("sub")
        if sub is None or not str(sub).startswith("child_"):
            raise credentials_exception
        profile_id = int(sub.split("_")[1])
    except (JWTError, ValueError):
        raise credentials_exception
        
    profile = db.query(Profile).filter(Profile.id == profile_id).first()
    if profile is None:
        raise credentials_exception
    if not profile.is_active:
        raise HTTPException(status_code=400, detail="Inactive profile")
        
    return profile

def verify_profile_access(profile_id: int, db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)):
    """
    Returns True if the token belongs to the child profile itself OR to its parent.
    Raises 401/403 otherwise.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        sub = payload.get("sub")
        if sub is None:
            raise credentials_exception
            
        if str(sub).startswith("child_"):
            token_profile_id = int(sub.split("_")[1])
            if token_profile_id != profile_id:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized for this profile")
            return True
            
        # Parent token
        user_id = int(sub)
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise credentials_exception
            
        profile = db.query(Profile).filter(Profile.id == profile_id, Profile.parent_id == user.id).first()
        if not profile:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized for this profile")
            
        return True
        
    except (JWTError, ValueError):
        raise credentials_exception

