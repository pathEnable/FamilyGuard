from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

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
    pairing_code = Column(String, nullable=True) # 6 digit code for device linking
    pairing_code_expires_at = Column(DateTime(timezone=True), nullable=True)
    is_active = Column(Boolean, default=True)
    is_locked = Column(Boolean, default=False)
    
    # Gamification fields
    total_points = Column(Integer, default=0)
    current_streak = Column(Integer, default=0)
    best_streak = Column(Integer, default=0)
    avatar_level = Column(Integer, default=1)
    
    # Web Filtering
    strict_web_filter = Column(Boolean, default=False)

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
    web_filter_rules = relationship("WebFilterRule", back_populates="profile", cascade="all, delete-orphan")
    quiz_questions = relationship("QuizQuestion", back_populates="profile", cascade="all, delete-orphan")
    quiz_attempts = relationship("QuizAttempt", back_populates="profile", cascade="all, delete-orphan")
