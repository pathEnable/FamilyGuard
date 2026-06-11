from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, Date, Time, Float, JSON, Enum as SAEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base
import enum


class RuleType(str, enum.Enum):
    DAILY_LIMIT = "DAILY_LIMIT"
    BEDTIME_BLOCK = "BEDTIME_BLOCK"
    EXAM_MODE = "EXAM_MODE"
    APP_BLOCK = "APP_BLOCK"


class User(Base):
    """
    Parent account that manages multiple child profiles.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    fcm_token = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    profiles = relationship("Profile", back_populates="parent")


class Profile(Base):
    """
    Child profile associated with a parent account.
    """
    __tablename__ = "profiles"

    id = Column(Integer, primary_key=True, index=True)
    parent_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)
    age = Column(Integer, nullable=False)
    avatar_url = Column(String, nullable=True)
    pin_code = Column(String, nullable=True) # Optional code to switch profiles
    is_active = Column(Boolean, default=True)
    is_locked = Column(Boolean, default=False)
    
    # Gamification fields
    total_points = Column(Integer, default=0)
    current_streak = Column(Integer, default=0)
    best_streak = Column(Integer, default=0)
    avatar_level = Column(Integer, default=1)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    parent = relationship("User", back_populates="profiles")
    time_rules = relationship("TimeRule", back_populates="profile", cascade="all, delete-orphan")
    safe_zones = relationship("SafeZone", back_populates="profile", cascade="all, delete-orphan")
    app_usages = relationship("AppUsage", back_populates="profile", cascade="all, delete-orphan")
    activity_logs = relationship("ActivityLog", back_populates="profile", cascade="all, delete-orphan")
    
    # Gamification relationships
    point_transactions = relationship("PointTransaction", back_populates="profile", cascade="all, delete-orphan")
    badges = relationship("Badge", back_populates="profile", cascade="all, delete-orphan")
    rewards = relationship("Reward", back_populates="profile", cascade="all, delete-orphan")
    quests = relationship("Quest", back_populates="profile", cascade="all, delete-orphan")


class SafeZone(Base):
    """Zones de sécurité (Geofencing)"""
    __tablename__ = "safe_zones"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    name = Column(String, nullable=False) # e.g. "Ecole", "Maison"
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    radius_meters = Column(Float, nullable=False, default=100.0)
    start_time = Column(Time, nullable=True) # Heure de début de surveillance
    end_time = Column(Time, nullable=True)   # Heure de fin de surveillance
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    profile = relationship("Profile", back_populates="safe_zones")


class PointTransaction(Base):
    """Historique des points gagnés/dépensés."""
    __tablename__ = "point_transactions"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    amount = Column(Integer, nullable=False) # Can be positive (earned) or negative (spent)
    reason = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    profile = relationship("Profile", back_populates="point_transactions")


class BadgeType(str, enum.Enum):
    BRONZE_3D = "BRONZE_3D"
    SILVER_7D = "SILVER_7D"
    GOLD_30D = "GOLD_30D"
    CUSTOM = "CUSTOM"


class Badge(Base):
    """Médailles débloquées par l'enfant."""
    __tablename__ = "badges"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    badge_type = Column(SAEnum(BadgeType), nullable=False)
    name = Column(String, nullable=False)
    icon_emoji = Column(String, nullable=False)
    unlocked_at = Column(DateTime(timezone=True), server_default=func.now())

    profile = relationship("Profile", back_populates="badges")


class Reward(Base):
    """Récompenses créées par le parent."""
    __tablename__ = "rewards"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    bonus_minutes = Column(Integer, nullable=False, default=0)
    point_cost = Column(Integer, nullable=False)
    is_claimed = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    claimed_at = Column(DateTime(timezone=True), nullable=True)

    profile = relationship("Profile", back_populates="rewards")


class QuestStatus(str, enum.Enum):
    PENDING = "PENDING"
    COMPLETED_BY_CHILD = "COMPLETED_BY_CHILD"
    VALIDATED = "VALIDATED"


class Quest(Base):
    """Missions (tâches ménagères, devoirs) pour gagner des points."""
    __tablename__ = "quests"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    points_reward = Column(Integer, nullable=False, default=10)
    status = Column(SAEnum(QuestStatus), default=QuestStatus.PENDING, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    completed_at = Column(DateTime(timezone=True), nullable=True)

    profile = relationship("Profile", back_populates="quests")


class TimeRule(Base):
    """
    Screen time rule for a child profile.
    - DAILY_LIMIT: max_minutes_per_day defines the allowed screen time.
    - BEDTIME_BLOCK: start_time/end_time define when the device is blocked.
    - EXAM_MODE: strict block during time with allowed apps bypass.
    """
    __tablename__ = "time_rules"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    rule_type = Column(SAEnum(RuleType), nullable=False)
    max_minutes_per_day = Column(Integer, nullable=True)  # For DAILY_LIMIT
    start_time = Column(Time, nullable=True)  # For BEDTIME_BLOCK / EXAM_MODE
    end_time = Column(Time, nullable=True)    # For BEDTIME_BLOCK / EXAM_MODE
    allowed_apps = Column(JSON, nullable=True) # List of package names for EXAM_MODE
    blocked_apps = Column(JSON, nullable=True) # List of package names for APP_BLOCK (VPN)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    profile = relationship("Profile", back_populates="time_rules")


class AppUsage(Base):
    """
    Daily usage tracking for a child profile.
    One row per profile per day.
    """
    __tablename__ = "app_usages"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    date = Column(Date, nullable=False)
    minutes_used = Column(Integer, default=0)

    profile = relationship("Profile", back_populates="app_usages")


class ActivityType(str, enum.Enum):
    SOS_TRIGGERED = "SOS_TRIGGERED"
    WEB_BLOCKED = "WEB_BLOCKED"
    TIME_LIMIT_REACHED = "TIME_LIMIT_REACHED"
    GEOFENCE_ALERT = "GEOFENCE_ALERT"
    CYBERBULLYING_DETECTED = "CYBERBULLYING_DETECTED"

class ActivityLog(Base):
    """
    Activity logs for tracking child's events.
    """
    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    activity_type = Column(SAEnum(ActivityType), nullable=False)
    description = Column(String, nullable=True) # E.g., the URL blocked
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    profile = relationship("Profile", back_populates="activity_logs")
