from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Response
from sqlalchemy.orm import Session
from datetime import date
from app.core.database import get_db
from app.api.deps import get_current_user
from app.models import User, Profile
from app.services.pdf_report import generate_weekly_report
from app.services.email_service import send_weekly_report_email

router = APIRouter()

@router.get("/{profile_id}/latest.pdf")
def get_latest_pdf_report(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Télécharge le rapport PDF de la semaine pour le profil donné.
    """
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profil introuvable")

    try:
        pdf_bytes = generate_weekly_report(db, profile)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'inline; filename="rapport_{profile.name}.pdf"'
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la génération du PDF: {str(e)}")

@router.post("/{profile_id}/send-report")
def send_activity_report(
    profile_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Génère et envoie le rapport PDF par email au parent.
    """
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profil introuvable")
        
    if not current_user.email:
        raise HTTPException(status_code=400, detail="L'email du parent n'est pas configuré.")
        
    # Generate PDF inline to ensure it succeeds before scheduling email,
    # or we could generate it in the background task entirely to save response time.
    # For now, we generate in background to keep API fast.
    
    def background_generate_and_send():
        try:
            pdf_bytes = generate_weekly_report(db, profile)
            send_weekly_report_email(current_user.email, profile.name, pdf_bytes)
        except Exception as e:
            print(f"Erreur envoi email: {e}")

    background_tasks.add_task(background_generate_and_send)

    return {"status": "success", "message": "Le rapport d'activité a été planifié pour l'envoi."}

