from app.models import ActivityLog


def test_trigger_sos(client, auth_headers, test_profile, db_session):
    response = client.post(
        f"/api/v1/profiles/{test_profile.id}/sos",
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "SOS triggered" in data["message"]

    # Verify an activity log was persisted
    logs = db_session.query(ActivityLog).filter(
        ActivityLog.profile_id == test_profile.id
    ).all()
    assert len(logs) == 1
    assert "SOS" in logs[0].description


def test_trigger_sos_wrong_profile(client, auth_headers):
    response = client.post(
        "/api/v1/profiles/9999/sos",
        headers=auth_headers,
    )
    assert response.status_code == 404
