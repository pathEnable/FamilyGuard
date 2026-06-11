from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_password, get_password_hash, create_access_token
from app.models.user import User
from app.schemas.user import UserCreate, User as UserSchema
from app.api.deps import get_current_user

router = APIRouter()

@router.post("/register", response_model=UserSchema, status_code=status.HTTP_201_CREATED)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
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
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
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

from pydantic import BaseModel
class FCMTokenRequest(BaseModel):
    token: str

@router.post("/fcm-token")
def update_fcm_token(req: FCMTokenRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    current_user.fcm_token = req.token
    db.commit()
    return {"message": "FCM token updated successfully"}

from app.schemas.user import ForgotPasswordRequest, ResetPasswordRequest
import secrets
from datetime import datetime, timedelta

# Simule une DB de tokens de reset en mémoire (pour la V1)
reset_tokens = {}

@router.post("/forgot-password")
def forgot_password(req: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if user:
        token = secrets.token_urlsafe(32)
        reset_tokens[token] = {
            "email": req.email,
            "expires": datetime.utcnow() + timedelta(hours=1)
        }
        # Simulation de l'envoi d'email
        print(f"\n==================================================")
        print(f"📧 EMAIL SIMULÉ POUR: {req.email}")
        print(f"🔗 LIEN DE RÉINITIALISATION: http://localhost:3000/reset-password?token={token}")
        print(f"==================================================\n")
    
    # Toujours renvoyer un succès pour ne pas fuiter les emails existants
    return {"status": "success", "message": "Si l'email existe, un lien de réinitialisation a été envoyé."}

@router.post("/reset-password")
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    token_data = reset_tokens.get(req.token)
    
    if not token_data or token_data["expires"] < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Token invalide ou expiré")
        
    user = db.query(User).filter(User.email == token_data["email"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
        
    user.hashed_password = get_password_hash(req.new_password)
    db.commit()
    
    # Clean up token
    del reset_tokens[req.token]
    
    return {"status": "success", "message": "Mot de passe réinitialisé avec succès"}
