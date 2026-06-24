import enum
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, JSON, Enum as SAEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


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


class QuizQuestion(Base):
    """Questions de Quiz (Globales si profile_id=None, ou Personnalisées)"""
    __tablename__ = "quiz_questions"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=True) # Null = global question
    category = Column(String, nullable=False)
    question = Column(String, nullable=False)
    options = Column(JSON, nullable=False) # List of 4 strings
    correct_index = Column(Integer, nullable=False)
    points = Column(Integer, nullable=False, default=5)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    profile = relationship("Profile", back_populates="quiz_questions")
    attempts = relationship("QuizAttempt", back_populates="question", cascade="all, delete-orphan")

class QuizAttempt(Base):
    """Historique des tentatives de Quiz pour limiter les gains répétitifs."""
    __tablename__ = "quiz_attempts"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("quiz_questions.id"), nullable=False)
    is_correct = Column(Boolean, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    profile = relationship("Profile", back_populates="quiz_attempts")
    question = relationship("QuizQuestion", back_populates="attempts")
