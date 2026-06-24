import enum
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Date, Enum as SAEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class ActivityType(str, enum.Enum):
    SOS_TRIGGERED = "SOS_TRIGGERED"
    WEB_BLOCKED = "WEB_BLOCKED"
    TIME_LIMIT_REACHED = "TIME_LIMIT_REACHED"
    GEOFENCE_ALERT = "GEOFENCE_ALERT"
    CYBERBULLYING_DETECTED = "CYBERBULLYING_DETECTED"
    EXPLICIT_SEARCH = "EXPLICIT_SEARCH"

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


class AppUsage(Base):
    """
    Daily usage tracking for a child profile.
    One row per profile per day per package.
    """
    __tablename__ = "app_usages"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    package_name = Column(String, nullable=False)
    app_name = Column(String, nullable=True)
    date = Column(Date, nullable=False)
    minutes_used = Column(Integer, default=0)

    profile = relationship("Profile", back_populates="app_usages")
