"""
Scheduled tasks for FamilyGuard.
Uses APScheduler to run the weekly report job every Sunday at 20:00.
"""

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from datetime import date

from app.core.database import SessionLocal
from app.models.user import User, Profile
from app.services.pdf_report import generate_weekly_report
from app.services.email_service import send_weekly_report_email


scheduler = BackgroundScheduler()


def send_all_weekly_reports():
    """
    Generate and send weekly PDF reports for ALL child profiles.
    Called automatically every Sunday at 20:00.
    """
    print("[SCHEDULER] Starting weekly report generation...")
    db = SessionLocal()
    try:
        # Get all parent users with their profiles
        parents = db.query(User).filter(User.is_active == True).all()
        
        reports_sent = 0
        reports_failed = 0
        
        for parent in parents:
            profiles = db.query(Profile).filter(
                Profile.parent_id == parent.id,
                Profile.is_active == True,
            ).all()
            
            for profile in profiles:
                try:
                    # Generate PDF
                    pdf_bytes = generate_weekly_report(db, profile)
                    
                    # Send email
                    success = send_weekly_report_email(
                        to_email=parent.email,
                        child_name=profile.name,
                        pdf_bytes=pdf_bytes,
                    )
                    
                    if success:
                        reports_sent += 1
                    else:
                        reports_failed += 1
                        
                except Exception as e:
                    print(f"[SCHEDULER] Error generating report for {profile.name}: {e}")
                    reports_failed += 1
        
        print(f"[SCHEDULER] Weekly reports complete: {reports_sent} sent, {reports_failed} failed.")
        
    except Exception as e:
        print(f"[SCHEDULER] Fatal error in weekly report job: {e}")
    finally:
        db.close()


def start_scheduler():
    """Initialize and start the background scheduler."""
    # Run every Sunday at 20:00
    scheduler.add_job(
        send_all_weekly_reports,
        trigger=CronTrigger(day_of_week="sun", hour=20, minute=0),
        id="weekly_reports",
        name="Weekly PDF Reports",
        replace_existing=True,
    )
    scheduler.start()
    print("[SCHEDULER] Started — Weekly reports scheduled for Sunday 20:00")


def stop_scheduler():
    """Gracefully shut down the scheduler."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        print("[SCHEDULER] Stopped.")
