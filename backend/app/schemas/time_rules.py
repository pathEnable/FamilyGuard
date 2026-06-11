from pydantic import BaseModel, field_validator
from typing import Optional, List
from datetime import datetime, time, date
from enum import Enum


class RuleType(str, Enum):
    DAILY_LIMIT = "DAILY_LIMIT"
    BEDTIME_BLOCK = "BEDTIME_BLOCK"
    EXAM_MODE = "EXAM_MODE"
    APP_BLOCK = "APP_BLOCK"


# --- TimeRule Schemas ---

class TimeRuleCreate(BaseModel):
    rule_type: RuleType
    max_minutes_per_day: Optional[int] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    allowed_apps: Optional[List[str]] = None
    blocked_apps: Optional[List[str]] = None
    is_active: bool = True

    @field_validator("max_minutes_per_day")
    @classmethod
    def validate_minutes(cls, v, info):
        if v is not None and (v < 1 or v > 1440):
            raise ValueError("max_minutes_per_day must be between 1 and 1440")
        return v


class TimeRuleResponse(BaseModel):
    id: int
    profile_id: int
    rule_type: RuleType
    max_minutes_per_day: Optional[int] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    allowed_apps: Optional[List[str]] = None
    blocked_apps: Optional[List[str]] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class TimeRuleUpdate(BaseModel):
    max_minutes_per_day: Optional[int] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    allowed_apps: Optional[List[str]] = None
    blocked_apps: Optional[List[str]] = None
    is_active: Optional[bool] = None


# --- AppUsage Schemas ---

class AppUsageResponse(BaseModel):
    id: int
    profile_id: int
    date: date
    minutes_used: int

    class Config:
        from_attributes = True


class TimeUsageReport(BaseModel):
    minutes: int = 1


# --- Time Status (for the child app) ---

class TimeStatus(BaseModel):
    """
    Returned to the child app to display the timer.
    """
    profile_id: int
    profile_name: str
    date: date
    daily_limit_minutes: Optional[int] = None
    minutes_used: int = 0
    minutes_remaining: Optional[int] = None
    is_bedtime_blocked: bool = False
    is_manually_blocked: bool = False
    is_exam_mode: bool = False
    bedtime_start: Optional[time] = None
    bedtime_end: Optional[time] = None
    allowed_apps: Optional[List[str]] = None
    blocked_network_apps: Optional[List[str]] = None
