from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_password, get_password_hash, create_access_token
from app.models import User, PasswordResetToken, Profile
from app.schemas.user import UserCreate, User as UserSchema
from app.schemas.user import ForgotPasswordRequest, ResetPasswordRequest
from app.api.deps import get_current_user
from app.core.rate_limit import RateLimiter
import secrets
from datetime import datetime, timedelta, timezone

router = APIRouter()

@router.post("/register", response_model=UserSchema, status_code=status.HTTP_201_CREATED)
@RateLimiter(requests=3, window=3600)
def register(request: Request, user_in: UserCreate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(status_code=400, detail="Email already registered")
        
    hashed_password = get_password_hash(user_in.password)
    new_user = User(email=user_in.email, hashed_password=hashed_password)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@router.post("/login")
@RateLimiter(requests=5, window=60)
def login(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(subject=user.id)
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=UserSchema)
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

class FCMTokenRequest(BaseModel):
    token: str

@router.post("/fcm-token")
def update_fcm_token(req: FCMTokenRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    current_user.fcm_token = req.token
    db.commit()
    return {"message": "FCM token updated successfully"}


@router.post("/forgot-password")
@RateLimiter(requests=3, window=300)
def forgot_password(request: Request, req: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if user:
        token = secrets.token_urlsafe(32)
        reset_token = PasswordResetToken(
            user_id=user.id,
            token=token,
            expires_at=datetime.now(timezone.utc) + timedelta(hours=1)
        )
        db.add(reset_token)
        db.commit()
        
        # Simulation de l'envoi d'email
        print(f"\n==================================================")
        print(f"📧 EMAIL SIMULÉ POUR: {req.email}")
        print(f"🔗 LIEN DE RÉINITIALISATION: http://localhost:3000/reset-password?token={token}")
        print(f"==================================================\n")
    
    # Toujours renvoyer un succès pour ne pas fuiter les emails existants
    return {"status": "success", "message": "Si l'email existe, un lien de réinitialisation a été envoyé."}

@router.post("/reset-password")
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    token_entry = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == req.token,
        PasswordResetToken.is_used == False
    ).first()
    
    if not token_entry or token_entry.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Token invalide ou expiré")
        
    user = db.query(User).filter(User.id == token_entry.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
        
    user.hashed_password = get_password_hash(req.new_password)
    token_entry.is_used = True
    db.commit()
    
    return {"status": "success", "message": "Mot de passe réinitialisé avec succès"}

class PairDeviceRequest(BaseModel):
    pairing_code: str

@router.post("/pair-device")
def pair_device(req: PairDeviceRequest, db: Session = Depends(get_db)):
    profile = db.query(Profile).filter(Profile.pairing_code == req.pairing_code.strip()).first()
    
    if not profile:
        raise HTTPException(status_code=400, detail="Code de liaison invalide ou introuvable.")
        
    if profile.pairing_code_expires_at:
        expires_at = profile.pairing_code_expires_at
        # SQLite returns naive datetimes; normalize to UTC-aware for comparison
        if expires_at.tzinfo is None:
            from datetime import timezone as tz
            expires_at = expires_at.replace(tzinfo=tz.utc)
        if expires_at < datetime.now(timezone.utc):
            raise HTTPException(status_code=400, detail="Ce code de liaison a expiré. Veuillez en générer un nouveau.")
        
    # Valid code, clear it
    profile.pairing_code = None
    profile.pairing_code_expires_at = None
    db.commit()
    
    # Generate child JWT
    access_token = create_access_token(subject=f"child_{profile.id}")
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "profile": {
            "id": profile.id,
            "parent_id": profile.parent_id,
            "name": profile.name,
            "avatar_url": profile.avatar_url,
            "strict_web_filter": profile.strict_web_filter
        }
    }
