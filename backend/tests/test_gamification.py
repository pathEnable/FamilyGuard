import pytest
from app.api.gamification import add_points, award_badge
from app.models import Profile, Badge
from app.models.gamification import PointTransaction, BadgeType

def test_add_points(db_session, test_profile):
    assert test_profile.total_points == 0  # profile créé avec 0 points dans conftest
    assert test_profile.avatar_level == 1
    
    # Ajouter 110 pts → passage au niveau 2 (seuil = 100)
    add_points(db_session, test_profile, 110, "Test ajout de points")
    
    assert test_profile.total_points == 110
    assert test_profile.avatar_level == 2
    
    # Vérifier l'historique des transactions
    history = db_session.query(PointTransaction).filter(PointTransaction.profile_id == test_profile.id).all()
    assert len(history) == 1
    assert history[0].amount == 110
    assert history[0].reason == "Test ajout de points"

def test_award_badge(db_session, test_profile):
    # Attribuer un badge
    award_badge(db_session, test_profile, BadgeType.BRONZE_3D, "Bronze 3 Jours", "🥉", points=20)
    
    # Vérifier que le badge est bien enregistré
    badges = db_session.query(Badge).filter(Badge.profile_id == test_profile.id).all()
    assert len(badges) == 1
    assert badges[0].badge_type == BadgeType.BRONZE_3D
    
    # Tenter de réattribuer le même badge (ne doit pas créer de doublon)
    award_badge(db_session, test_profile, BadgeType.BRONZE_3D, "Bronze 3 Jours", "🥉", points=20)
    
    badges_after = db_session.query(Badge).filter(Badge.profile_id == test_profile.id).all()
    assert len(badges_after) == 1  # Toujours 1, pas de doublon

