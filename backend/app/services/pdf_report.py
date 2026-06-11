"""
Weekly PDF Report Generator for FamilyGuard.
Generates a visual summary of a child's week sent to the parent every Sunday.
"""

import io
import os
import tempfile
from datetime import date, timedelta
from typing import List, Optional

from fpdf import FPDF
from sqlalchemy.orm import Session

from app.models.user import (
    Profile, AppUsage, ActivityLog, ActivityType,
    PointTransaction, Badge
)


class WeeklyReportPDF(FPDF):
    """Custom PDF class for FamilyGuard weekly reports."""

    # ── Brand colors ──
    PRIMARY = (37, 99, 235)       # Blue #2563EB
    SUCCESS = (16, 185, 129)      # Green #10B981
    WARNING = (249, 115, 22)      # Orange #F97316
    DANGER = (239, 68, 68)        # Red #EF4444
    DARK = (30, 41, 59)           # Slate-800
    LIGHT_BG = (248, 250, 252)    # Slate-50

    def header(self):
        self.set_font("Helvetica", "B", 20)
        self.set_text_color(*self.PRIMARY)
        self.cell(0, 12, "FamilyGuard", align="L")
        self.set_font("Helvetica", "", 10)
        self.set_text_color(120, 120, 120)
        self.cell(0, 12, "Rapport Hebdomadaire", align="R", new_x="LMARGIN", new_y="NEXT")
        # Separator line
        self.set_draw_color(*self.PRIMARY)
        self.set_line_width(0.5)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(6)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(160, 160, 160)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

    def section_title(self, title: str, emoji: str = ""):
        self.set_font("Helvetica", "B", 14)
        self.set_text_color(*self.DARK)
        self.cell(0, 10, f"{emoji}  {title}", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*self.PRIMARY)
        self.set_line_width(0.3)
        self.line(10, self.get_y(), 80, self.get_y())
        self.ln(4)

    def info_box(self, label: str, value: str, color: tuple = None):
        """Small colored info box."""
        if color is None:
            color = self.PRIMARY
        x = self.get_x()
        y = self.get_y()
        w = 55
        h = 22

        # Background
        self.set_fill_color(color[0], color[1], color[2])
        self.set_draw_color(color[0], color[1], color[2])
        self.rect(x, y, w, h, "F")

        # Value
        self.set_xy(x, y + 2)
        self.set_font("Helvetica", "B", 16)
        self.set_text_color(255, 255, 255)
        self.cell(w, 8, value, align="C", new_x="LEFT", new_y="NEXT")

        # Label
        self.set_xy(x, y + 11)
        self.set_font("Helvetica", "", 8)
        self.set_text_color(230, 230, 240)
        self.cell(w, 6, label, align="C")

        self.set_xy(x + w + 5, y)


def generate_weekly_report(db: Session, profile: Profile, week_end: date = None) -> bytes:
    """
    Generate a weekly PDF report for a child profile.
    
    Args:
        db: Database session
        profile: The child profile to generate the report for
        week_end: The end date of the week (defaults to today)
    
    Returns:
        PDF content as bytes
    """
    if week_end is None:
        week_end = date.today()
    week_start = week_end - timedelta(days=6)

    # ── Fetch data ──
    usages: List[AppUsage] = (
        db.query(AppUsage)
        .filter(
            AppUsage.profile_id == profile.id,
            AppUsage.date >= week_start,
            AppUsage.date <= week_end,
        )
        .order_by(AppUsage.date)
        .all()
    )

    alerts: List[ActivityLog] = (
        db.query(ActivityLog)
        .filter(
            ActivityLog.profile_id == profile.id,
            ActivityLog.created_at >= str(week_start),
        )
        .order_by(ActivityLog.created_at.desc())
        .all()
    )

    transactions: List[PointTransaction] = (
        db.query(PointTransaction)
        .filter(
            PointTransaction.profile_id == profile.id,
            PointTransaction.created_at >= str(week_start),
        )
        .all()
    )

    badges: List[Badge] = (
        db.query(Badge)
        .filter(Badge.profile_id == profile.id)
        .order_by(Badge.unlocked_at.desc())
        .limit(5)
        .all()
    )

    # ── Build usage map ──
    usage_map = {}
    for u in usages:
        usage_map[u.date] = u.minutes_used

    days = []
    for i in range(7):
        d = week_start + timedelta(days=i)
        days.append((d, usage_map.get(d, 0)))

    total_minutes = sum(m for _, m in days)
    avg_minutes = total_minutes / 7 if days else 0
    max_day = max(days, key=lambda x: x[1]) if days else (week_start, 0)

    # ── Categorize alerts ──
    sos_count = sum(1 for a in alerts if a.activity_type == ActivityType.SOS_TRIGGERED)
    web_blocked_count = sum(1 for a in alerts if a.activity_type == ActivityType.WEB_BLOCKED)
    geofence_count = sum(1 for a in alerts if a.activity_type == ActivityType.GEOFENCE_ALERT)
    cyber_count = sum(1 for a in alerts if a.activity_type == ActivityType.CYBERBULLYING_DETECTED)
    time_limit_count = sum(1 for a in alerts if a.activity_type == ActivityType.TIME_LIMIT_REACHED)

    # ── Generate PDF ──
    pdf = WeeklyReportPDF()
    pdf.alias_nb_pages()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=20)

    # ── Title ──
    pdf.set_font("Helvetica", "B", 18)
    pdf.set_text_color(*WeeklyReportPDF.DARK)
    pdf.cell(0, 10, f"Rapport de {profile.name}", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    pdf.set_text_color(120, 120, 120)
    pdf.cell(
        0, 8,
        f"Semaine du {week_start.strftime('%d/%m/%Y')} au {week_end.strftime('%d/%m/%Y')}",
        new_x="LMARGIN", new_y="NEXT",
    )
    pdf.ln(6)

    # ── Summary boxes ──
    pdf.section_title("Resume de la semaine", "")

    start_y = pdf.get_y()
    pdf.info_box("Temps total", f"{total_minutes // 60}h {total_minutes % 60}m", WeeklyReportPDF.PRIMARY)
    pdf.info_box("Moyenne / jour", f"{int(avg_minutes)}min", WeeklyReportPDF.SUCCESS)
    pdf.info_box("Alertes", str(len(alerts)), WeeklyReportPDF.DANGER if alerts else WeeklyReportPDF.SUCCESS)
    pdf.set_y(start_y + 28)
    pdf.ln(4)

    # ── Bar chart: Daily usage ──
    pdf.section_title("Temps d'ecran quotidien", "")

    day_names = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
    chart_x = 15
    chart_y = pdf.get_y()
    chart_w = 170
    chart_h = 60
    max_minutes = max(m for _, m in days) if any(m > 0 for _, m in days) else 120
    bar_width = chart_w / 7 - 4

    # Background
    pdf.set_fill_color(*WeeklyReportPDF.LIGHT_BG)
    pdf.rect(chart_x, chart_y, chart_w, chart_h, "F")

    # Grid lines
    pdf.set_draw_color(220, 220, 230)
    pdf.set_line_width(0.1)
    for i in range(1, 4):
        y_line = chart_y + chart_h - (chart_h * i / 4)
        pdf.line(chart_x, y_line, chart_x + chart_w, y_line)
        pdf.set_xy(chart_x + chart_w + 1, y_line - 3)
        pdf.set_font("Helvetica", "", 7)
        pdf.set_text_color(160, 160, 160)
        pdf.cell(15, 6, f"{int(max_minutes * i / 4)}m")

    for i, (d, minutes) in enumerate(days):
        bx = chart_x + i * (bar_width + 4) + 2
        bar_height = (minutes / max_minutes * (chart_h - 10)) if max_minutes > 0 else 0
        by = chart_y + chart_h - bar_height - 2

        # Bar color (gradient from green to orange to red)
        ratio = minutes / max_minutes if max_minutes > 0 else 0
        if ratio <= 0.5:
            color = WeeklyReportPDF.SUCCESS
        elif ratio <= 0.8:
            color = WeeklyReportPDF.WARNING
        else:
            color = WeeklyReportPDF.DANGER

        pdf.set_fill_color(*color)
        if bar_height > 0:
            pdf.rect(bx, by, bar_width, bar_height, "F")

        # Value on top of bar
        pdf.set_font("Helvetica", "B", 7)
        pdf.set_text_color(*WeeklyReportPDF.DARK)
        pdf.set_xy(bx, by - 6)
        pdf.cell(bar_width, 6, f"{minutes}m", align="C")

        # Day label below
        pdf.set_font("Helvetica", "", 8)
        pdf.set_text_color(100, 100, 100)
        pdf.set_xy(bx, chart_y + chart_h + 1)
        day_idx = d.weekday()
        pdf.cell(bar_width, 6, day_names[day_idx], align="C")

    pdf.set_y(chart_y + chart_h + 12)

    # ── Alerts summary ──
    if alerts:
        pdf.section_title("Alertes et evenements", "")

        alert_data = [
            ("SOS declenche", sos_count, WeeklyReportPDF.DANGER),
            ("Sites bloques", web_blocked_count, WeeklyReportPDF.WARNING),
            ("Sorties de zone", geofence_count, WeeklyReportPDF.WARNING),
            ("Cyberharcelement", cyber_count, WeeklyReportPDF.DANGER),
            ("Limites atteintes", time_limit_count, WeeklyReportPDF.PRIMARY),
        ]

        for label, count, color in alert_data:
            if count > 0:
                pdf.set_font("Helvetica", "", 10)
                pdf.set_text_color(*color)
                pdf.cell(6, 6, chr(0xB7))  # Middle dot (latin-1 safe)
                pdf.set_text_color(*WeeklyReportPDF.DARK)
                pdf.cell(60, 6, label)
                pdf.set_font("Helvetica", "B", 10)
                pdf.cell(20, 6, str(count), new_x="LMARGIN", new_y="NEXT")

        pdf.ln(4)

    # ── Gamification ──
    pdf.section_title("Gamification", "")

    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(*WeeklyReportPDF.DARK)

    points_earned = sum(t.amount for t in transactions if t.amount > 0)
    points_spent = abs(sum(t.amount for t in transactions if t.amount < 0))

    pdf.cell(50, 7, "Points totaux:")
    pdf.set_font("Helvetica", "B", 10)
    pdf.cell(30, 7, str(profile.total_points), new_x="LMARGIN", new_y="NEXT")

    pdf.set_font("Helvetica", "", 10)
    pdf.cell(50, 7, f"Points gagnes cette semaine:")
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(*WeeklyReportPDF.SUCCESS)
    pdf.cell(30, 7, f"+{points_earned}", new_x="LMARGIN", new_y="NEXT")

    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(*WeeklyReportPDF.DARK)
    pdf.cell(50, 7, "Serie actuelle:")
    pdf.set_font("Helvetica", "B", 10)
    pdf.cell(30, 7, f"{profile.current_streak} jour(s)", new_x="LMARGIN", new_y="NEXT")

    pdf.set_font("Helvetica", "", 10)
    pdf.cell(50, 7, "Niveau avatar:")
    pdf.set_font("Helvetica", "B", 10)
    pdf.cell(30, 7, f"Niv. {profile.avatar_level}", new_x="LMARGIN", new_y="NEXT")

    if badges:
        pdf.ln(2)
        pdf.set_font("Helvetica", "B", 10)
        pdf.set_text_color(*WeeklyReportPDF.DARK)
        pdf.cell(0, 7, "Dernieres medailles:", new_x="LMARGIN", new_y="NEXT")
        for badge in badges[:3]:
            pdf.set_font("Helvetica", "", 10)
            # Strip non-latin-1 chars (emojis) for safe PDF rendering
            safe_name = badge.name.encode("latin-1", errors="replace").decode("latin-1")
            pdf.cell(0, 7, f"  * {safe_name}", new_x="LMARGIN", new_y="NEXT")

    pdf.ln(6)

    # ── Footer note ──
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(160, 160, 160)
    pdf.cell(
        0, 10,
        "Ce rapport a ete genere automatiquement par FamilyGuard.",
        align="C",
    )

    # Return PDF as bytes
    return pdf.output()
