import enum
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, Time, Float, JSON, Enum as SAEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class RuleType(str, enum.Enum):
    DAILY_LIMIT = "DAILY_LIMIT"
    BEDTIME_BLOCK = "BEDTIME_BLOCK"
    EXAM_MODE = "EXAM_MODE"
    APP_BLOCK = "APP_BLOCK"

class FilterRuleType(str, enum.Enum):
    WHITELIST = "WHITELIST"
    BLACKLIST = "BLACKLIST"


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


class WebFilterRule(Base):
    """
    Règle de filtrage web spécifique à un enfant (Liste blanche ou noire).
    """
    __tablename__ = "web_filter_rules"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    url_pattern = Column(String, nullable=False)
    rule_type = Column(SAEnum(FilterRuleType), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    profile = relationship("Profile", back_populates="web_filter_rules")


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
