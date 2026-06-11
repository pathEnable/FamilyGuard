"""
Reports API — allows parents to download or trigger weekly PDF reports.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session
from datetime import date, timedelta

from app.core.database import get_db
from app.models.user import User, Profile
from app.api.deps import get_current_user
from app.services.pdf_report import generate_weekly_report
from app.services.email_service import send_weekly_report_email

router = APIRouter()


@router.get("/{profile_id}/weekly-pdf")
def download_weekly_report(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Download the weekly PDF report for a child profile.
    Returns the PDF directly as a file download.
    """
    profile = db.query(Profile).filter(
        Profile.id == profile_id,
        Profile.parent_id == current_user.id,
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profil non trouvé")

    pdf_bytes = generate_weekly_report(db, profile)

    filename = f"FamilyGuard_Rapport_{profile.name}_{date.today().strftime('%Y%m%d')}.pdf"

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )


@router.post("/{profile_id}/send-weekly-email")
def send_weekly_report(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Manually trigger sending the weekly report email for a child profile.
    Useful for testing or on-demand reports.
    """
    profile = db.query(Profile).filter(
        Profile.id == profile_id,
        Profile.parent_id == current_user.id,
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profil non trouvé")

    pdf_bytes = generate_weekly_report(db, profile)

    success = send_weekly_report_email(
        to_email=current_user.email,
        child_name=profile.name,
        pdf_bytes=pdf_bytes,
    )

    if success:
        return {"detail": f"Rapport envoyé à {current_user.email}"}
    else:
        raise HTTPException(
            status_code=500,
            detail="Erreur lors de l'envoi. Vérifiez la configuration SMTP dans .env",
        )
