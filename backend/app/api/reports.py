from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from datetime import date, timedelta
from typing import List

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User, Profile, AppUsage, Quest, QuestStatus
from app.core.email import send_email

router = APIRouter()

def generate_report_html(profile: Profile, usage: List[AppUsage], completed_quests: List[Quest]) -> str:
    html = f"""
    <html>
    <head>
        <style>
            body {{ font-family: 'Arial', sans-serif; color: #333; }}
            h2 {{ color: #2563EB; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .section {{ margin-bottom: 20px; padding: 15px; background: #F8FAFC; border-radius: 8px; }}
            ul {{ list-style-type: none; padding: 0; }}
            li {{ padding: 8px 0; border-bottom: 1px solid #ddd; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Rapport d'Activité pour {profile.name}</h2>
            <p>Voici le résumé des activités récentes de {profile.name}.</p>
            
            <div class="section">
                <h3>Utilisation des Applications (Aujourd'hui)</h3>
                <ul>
    """
    
    if usage:
        for u in usage:
            html += f"<li><strong>{u.package_name}</strong>: {u.minutes_used} minutes</li>"
    else:
        html += "<li>Aucune utilisation enregistrée aujourd'hui.</li>"

    html += """
                </ul>
            </div>
            
            <div class="section">
                <h3>Quêtes Récentes (Validées ou Terminées)</h3>
                <ul>
    """
    
    if completed_quests:
        for q in completed_quests:
            status_fr = "Validée" if q.status == QuestStatus.VALIDATED else "En attente"
            html += f"<li><strong>{q.title}</strong> - {q.points_reward} pts ({status_fr})</li>"
    else:
        html += "<li>Aucune quête complétée récemment.</li>"

    html += f"""
                </ul>
            </div>
            
            <div class="section">
                <h3>Points Totaux: {profile.total_points}</h3>
            </div>
            
            <p style="font-size: 12px; color: #64748B; margin-top: 30px;">Ceci est un rapport automatique généré par FamilyGuard.</p>
        </div>
    </body>
    </html>
    """
    return html

@router.post("/{profile_id}/send-report")
def send_activity_report(
    profile_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    profile = next((p for p in current_user.profiles if p.id == profile_id), None)
    if not profile:
        raise HTTPException(status_code=404, detail="Profil introuvable")
        
    if not current_user.email:
        raise HTTPException(status_code=400, detail="L'email du parent n'est pas configuré.")
        
    today = date.today()
    
    usage_stats = db.query(AppUsage).filter(
        AppUsage.profile_id == profile_id,
        AppUsage.date == today
    ).all()
    
    recent_quests = db.query(Quest).filter(
        Quest.profile_id == profile_id,
        Quest.status.in_([QuestStatus.COMPLETED_BY_CHILD, QuestStatus.VALIDATED])
    ).order_by(Quest.updated_at.desc()).limit(10).all()
    
    html_content = generate_report_html(profile, usage_stats, recent_quests)
    
    # Run email sending in background
    background_tasks.add_task(
        send_email,
        to_email=current_user.email,
        subject=f"FamilyGuard : Rapport d'Activité de {profile.name}",
        html_content=html_content
    )

    return {"status": "success", "message": "Le rapport d'activité a été planifié pour l'envoi."}
