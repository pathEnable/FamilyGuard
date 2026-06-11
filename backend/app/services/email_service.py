"""
Email service for FamilyGuard.
Sends weekly PDF reports to parents via SMTP.
"""

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from datetime import date


# ── SMTP Configuration (set in .env) ──
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "FamilyGuard")
SMTP_FROM_EMAIL = os.getenv("SMTP_FROM_EMAIL", SMTP_USER)


def send_weekly_report_email(
    to_email: str,
    child_name: str,
    pdf_bytes: bytes,
    week_end: date = None,
) -> bool:
    """
    Send the weekly PDF report to a parent via email.
    
    Args:
        to_email: Parent's email address
        child_name: Name of the child profile
        pdf_bytes: The PDF report content
        week_end: The end date of the report week
    
    Returns:
        True if the email was sent successfully, False otherwise
    """
    if not SMTP_USER or not SMTP_PASSWORD:
        print("[EMAIL] SMTP not configured — skipping email send.")
        return False

    if week_end is None:
        week_end = date.today()

    week_start = week_end - __import__("datetime").timedelta(days=6)
    date_range = f"{week_start.strftime('%d/%m')} - {week_end.strftime('%d/%m/%Y')}"

    # ── Build the email ──
    msg = MIMEMultipart("mixed")
    msg["From"] = f"{SMTP_FROM_NAME} <{SMTP_FROM_EMAIL}>"
    msg["To"] = to_email
    msg["Subject"] = f"📊 Rapport hebdomadaire de {child_name} — {date_range}"

    # HTML body
    html_body = f"""
    <html>
    <body style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="text-align: center; padding: 20px 0; border-bottom: 2px solid #2563EB;">
            <h1 style="color: #2563EB; margin: 0;">🛡️ FamilyGuard</h1>
            <p style="color: #64748B; margin-top: 4px;">Rapport Hebdomadaire</p>
        </div>
        
        <div style="padding: 24px 0;">
            <h2 style="color: #1E293B;">Bonjour 👋</h2>
            <p style="color: #475569; line-height: 1.6;">
                Voici le rapport d'activité de <strong>{child_name}</strong> 
                pour la semaine du <strong>{date_range}</strong>.
            </p>
            <p style="color: #475569; line-height: 1.6;">
                Vous trouverez en pièce jointe un résumé détaillé incluant :
            </p>
            <ul style="color: #475569; line-height: 1.8;">
                <li>📱 Le temps d'écran quotidien</li>
                <li>🚨 Les alertes et événements de la semaine</li>
                <li>🏆 Les progrès de gamification</li>
            </ul>
        </div>
        
        <div style="background: #F8FAFC; border-radius: 12px; padding: 16px; text-align: center; margin: 16px 0;">
            <p style="color: #64748B; font-size: 14px; margin: 0;">
                📎 Le rapport PDF est en pièce jointe de cet email.
            </p>
        </div>
        
        <div style="text-align: center; padding: 20px 0; border-top: 1px solid #E2E8F0; margin-top: 24px;">
            <p style="color: #94A3B8; font-size: 12px; margin: 0;">
                Cet email a été envoyé automatiquement par FamilyGuard.<br>
                Ne répondez pas à ce message.
            </p>
        </div>
    </body>
    </html>
    """

    html_part = MIMEText(html_body, "html", "utf-8")
    msg.attach(html_part)

    # Attach PDF
    filename = f"FamilyGuard_Rapport_{child_name}_{week_end.strftime('%Y%m%d')}.pdf"
    pdf_attachment = MIMEApplication(pdf_bytes, _subtype="pdf")
    pdf_attachment.add_header("Content-Disposition", "attachment", filename=filename)
    msg.attach(pdf_attachment)

    # ── Send ──
    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
        print(f"[EMAIL] Report sent to {to_email} for {child_name}")
        return True
    except Exception as e:
        print(f"[EMAIL] Failed to send report to {to_email}: {e}")
        return False
