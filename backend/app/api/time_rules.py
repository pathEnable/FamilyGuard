from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import date, datetime
from app.core.database import get_db
from app.models.user import User, Profile, TimeRule, AppUsage, RuleType
from app.schemas.time_rules import (
    TimeRuleCreate, TimeRuleResponse, TimeRuleUpdate,
    AppUsageResponse, TimeStatus, TimeUsageReport
)
from app.api.deps import get_current_user
from app.api.ws import manager

router = APIRouter()


# ──────────────────────────────────────────────────────────
# PARENT ROUTES: Manage time rules for a child profile
# ──────────────────────────────────────────────────────────

def _get_profile_for_parent(profile_id: int, db: Session, current_user: User) -> Profile:
    """Helper: fetch a profile and verify ownership."""
    profile = db.query(Profile).filter(Profile.id == profile_id).first()
    if not profile or profile.parent_id != current_user.id:
        raise HTTPException(status_code=404, detail="Profil non trouvé")
    return profile


@router.post("/{profile_id}/rules", response_model=TimeRuleResponse)
async def create_time_rule(
    profile_id: int,
    rule_in: TimeRuleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new time rule for a child profile (parent only)."""
    profile = _get_profile_for_parent(profile_id, db, current_user)

    # Validate: DAILY_LIMIT needs max_minutes, BEDTIME/EXAM_MODE needs times
    if rule_in.rule_type == RuleType.DAILY_LIMIT and rule_in.max_minutes_per_day is None:
        raise HTTPException(status_code=400, detail="max_minutes_per_day requis pour DAILY_LIMIT")
    if rule_in.rule_type in [RuleType.BEDTIME_BLOCK, RuleType.EXAM_MODE]:
        if rule_in.start_time is None or rule_in.end_time is None:
            raise HTTPException(status_code=400, detail="start_time et end_time requis")
    if rule_in.rule_type == RuleType.APP_BLOCK:
        if not rule_in.blocked_apps:
            raise HTTPException(status_code=400, detail="blocked_apps requis pour APP_BLOCK")

    new_rule = TimeRule(
        profile_id=profile.id,
        rule_type=rule_in.rule_type,
        max_minutes_per_day=rule_in.max_minutes_per_day,
        start_time=rule_in.start_time,
        end_time=rule_in.end_time,
        allowed_apps=rule_in.allowed_apps,
        blocked_apps=rule_in.blocked_apps,
        is_active=rule_in.is_active,
    )
    db.add(new_rule)
    db.commit()
    db.refresh(new_rule)
    
    await manager.broadcast_to_parent(current_user.id, {
        "type": "rules_updated",
        "profile_id": profile.id,
        "action": "rule_created"
    })
    
    return new_rule


@router.get("/{profile_id}/rules", response_model=List[TimeRuleResponse])
def get_time_rules(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all time rules for a child profile (parent only)."""
    profile = _get_profile_for_parent(profile_id, db, current_user)
    return profile.time_rules


@router.put("/{profile_id}/rules/{rule_id}", response_model=TimeRuleResponse)
async def update_time_rule(
    profile_id: int,
    rule_id: int,
    rule_in: TimeRuleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update an existing time rule (parent only)."""
    _get_profile_for_parent(profile_id, db, current_user)
    rule = db.query(TimeRule).filter(TimeRule.id == rule_id, TimeRule.profile_id == profile_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail="Règle non trouvée")

    if rule_in.max_minutes_per_day is not None:
        rule.max_minutes_per_day = rule_in.max_minutes_per_day
    if rule_in.start_time is not None:
        rule.start_time = rule_in.start_time
    if rule_in.end_time is not None:
        rule.end_time = rule_in.end_time
    if rule_in.allowed_apps is not None:
        rule.allowed_apps = rule_in.allowed_apps
    if rule_in.blocked_apps is not None:
        rule.blocked_apps = rule_in.blocked_apps
    if rule_in.is_active is not None:
        rule.is_active = rule_in.is_active

    db.commit()
    db.refresh(rule)

    await manager.broadcast_to_parent(current_user.id, {
        "type": "rules_updated",
        "profile_id": profile_id,
        "action": "rule_updated"
    })

    return rule


@router.delete("/{profile_id}/rules/{rule_id}")
async def delete_time_rule(
    profile_id: int,
    rule_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a time rule (parent only)."""
    _get_profile_for_parent(profile_id, db, current_user)
    rule = db.query(TimeRule).filter(TimeRule.id == rule_id, TimeRule.profile_id == profile_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail="Règle non trouvée")
    db.delete(rule)
    db.commit()

    await manager.broadcast_to_parent(current_user.id, {
        "type": "rules_updated",
        "profile_id": profile_id,
        "action": "rule_deleted"
    })

    return {"detail": "Règle supprimée"}


# ──────────────────────────────────────────────────────────
# CHILD APP ROUTE: Get current time status for a profile
# ──────────────────────────────────────────────────────────

@router.get("/{profile_id}/time-status", response_model=TimeStatus)
def get_time_status(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get the current time status for a child profile.
    Used by the child app to display the countdown timer.
    """
    profile = _get_profile_for_parent(profile_id, db, current_user)
    today = date.today()
    now = datetime.now().time()

    # Get or create today's usage record
    usage = db.query(AppUsage).filter(
        AppUsage.profile_id == profile.id,
        AppUsage.date == today
    ).first()
    minutes_used = usage.minutes_used if usage else 0

    # Check daily limit
    daily_limit = None
    daily_rule = db.query(TimeRule).filter(
        TimeRule.profile_id == profile.id,
        TimeRule.rule_type == RuleType.DAILY_LIMIT,
        TimeRule.is_active == True,
    ).first()
    if daily_rule:
        daily_limit = daily_rule.max_minutes_per_day

    minutes_remaining = None
    if daily_limit is not None:
        minutes_remaining = max(0, daily_limit - minutes_used)

    # Check bedtime block
    is_bedtime = False
    bedtime_start = None
    bedtime_end = None
    bedtime_rule = db.query(TimeRule).filter(
        TimeRule.profile_id == profile.id,
        TimeRule.rule_type == RuleType.BEDTIME_BLOCK,
        TimeRule.is_active == True,
    ).first()
    if bedtime_rule:
        bedtime_start = bedtime_rule.start_time
        bedtime_end = bedtime_rule.end_time
        # Check if we are currently in bedtime (handles overnight blocks like 21:00-07:00)
        if bedtime_start and bedtime_end:
            if bedtime_start > bedtime_end:
                # Overnight: e.g. 21:00 -> 07:00
                is_bedtime = now >= bedtime_start or now <= bedtime_end
            else:
                is_bedtime = bedtime_start <= now <= bedtime_end

    # Check exam mode
    is_exam_mode = False
    allowed_apps = None
    exam_rule = db.query(TimeRule).filter(
        TimeRule.profile_id == profile.id,
        TimeRule.rule_type == RuleType.EXAM_MODE,
        TimeRule.is_active == True,
    ).first()
    if exam_rule and exam_rule.start_time and exam_rule.end_time:
        if exam_rule.start_time > exam_rule.end_time:
            is_exam_mode = now >= exam_rule.start_time or now <= exam_rule.end_time
        else:
            is_exam_mode = exam_rule.start_time <= now <= exam_rule.end_time
        
        if is_exam_mode:
            allowed_apps = exam_rule.allowed_apps

    # Check app blocking (VPN firewall)
    blocked_network_apps = []
    app_block_rules = db.query(TimeRule).filter(
        TimeRule.profile_id == profile.id,
        TimeRule.rule_type == RuleType.APP_BLOCK,
        TimeRule.is_active == True,
    ).all()
    for rule in app_block_rules:
        if rule.blocked_apps:
            blocked_network_apps.extend(rule.blocked_apps)

    return TimeStatus(
        profile_id=profile.id,
        profile_name=profile.name,
        date=today,
        daily_limit_minutes=daily_limit,
        minutes_used=minutes_used,
        minutes_remaining=minutes_remaining,
        is_bedtime_blocked=is_bedtime,
        is_manually_blocked=profile.is_locked,
        is_exam_mode=is_exam_mode,
        bedtime_start=bedtime_start,
        bedtime_end=bedtime_end,
        allowed_apps=allowed_apps,
        blocked_network_apps=blocked_network_apps if blocked_network_apps else None,
    )


# ──────────────────────────────────────────────────────────
# TIME USAGE REPORT ENDPOINT
# ──────────────────────────────────────────────────────────

@router.post("/{profile_id}/time-usage")
def report_time_usage(
    profile_id: int,
    report: TimeUsageReport,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Report active screen time usage.
    Called by the child app periodically (e.g. every minute).
    """
    profile = _get_profile_for_parent(profile_id, db, current_user)
    today = date.today()

    usage = db.query(AppUsage).filter(
        AppUsage.profile_id == profile.id,
        AppUsage.date == today
    ).first()

    old_minutes = usage.minutes_used if usage else 0
    new_minutes = old_minutes + report.minutes

    if not usage:
        usage = AppUsage(profile_id=profile.id, date=today, minutes_used=new_minutes)
        db.add(usage)
    else:
        usage.minutes_used = new_minutes

    db.commit()

    # Check if we just crossed the daily limit
    daily_rule = db.query(TimeRule).filter(
        TimeRule.profile_id == profile.id,
        TimeRule.rule_type == RuleType.DAILY_LIMIT,
        TimeRule.is_active == True,
    ).first()

    if daily_rule and daily_rule.max_minutes_per_day:
        limit = daily_rule.max_minutes_per_day
        if old_minutes < limit and new_minutes >= limit:
            # We just hit the limit
            if current_user.fcm_token:
                from app.core import firebase
                firebase.send_push_notification(
                    token=current_user.fcm_token,
                    title="Temps d'écran écoulé ⏱️",
                    body=f"Le temps d'écran de {profile.name} est terminé pour aujourd'hui.",
                    data={"type": "TIME_LIMIT", "profile_id": str(profile.id)}
                )

    return {"status": "success", "minutes_used": usage.minutes_used}
