from app.models import SafeZone, ActivityLog
import datetime

def test_update_location_no_safe_zone(client, auth_headers, test_profile):
    response = client.post(
        f"/api/v1/profiles/{test_profile.id}/location",
        headers=auth_headers,
        json={"latitude": 48.8566, "longitude": 2.3522}
    )
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_update_location_outside_safe_zone(client, auth_headers, test_profile, db_session):
    # Create an active safe zone
    zone = SafeZone(
        profile_id=test_profile.id,
        name="Home",
        latitude=40.7128,  # New York
        longitude=-74.0060,
        radius_meters=1000,
        is_active=True
    )
    db_session.add(zone)
    db_session.commit()

    # Ping from Paris (very far from NY)
    response = client.post(
        f"/api/v1/profiles/{test_profile.id}/location",
        headers=auth_headers,
        json={"latitude": 48.8566, "longitude": 2.3522}
    )
    assert response.status_code == 200
    
    # Verify an activity log was created for GEOFENCE_ALERT
    logs = db_session.query(ActivityLog).filter(ActivityLog.profile_id == test_profile.id).all()
    assert len(logs) == 1
    assert "Hors de la zone" in logs[0].description

def test_geofence_alert_exit(client, auth_headers, test_profile, db_session):
    response = client.post(
        f"/api/v1/profiles/{test_profile.id}/geofence-alert",
        headers=auth_headers,
        json={"zone_name": "School", "transition_type": "EXIT"}
    )
    assert response.status_code == 200
    assert response.json()["transition"] == "EXIT"
    
    logs = db_session.query(ActivityLog).filter(ActivityLog.profile_id == test_profile.id).all()
    assert any("Sorti(e) de la zone" in log.description for log in logs)
