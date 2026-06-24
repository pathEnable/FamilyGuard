def test_create_daily_limit_rule(client, auth_headers, test_profile):
    response = client.post(
        f"/api/v1/profiles/{test_profile.id}/rules",
        json={"rule_type": "DAILY_LIMIT", "max_minutes_per_day": 90, "is_active": True},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["rule_type"] == "DAILY_LIMIT"
    assert data["max_minutes_per_day"] == 90

def test_create_bedtime_rule(client, auth_headers, test_profile):
    response = client.post(
        f"/api/v1/profiles/{test_profile.id}/rules",
        json={"rule_type": "BEDTIME_BLOCK", "start_time": "21:00", "end_time": "07:00", "is_active": True},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["rule_type"] == "BEDTIME_BLOCK"

def test_list_rules(client, auth_headers, test_profile):
    # Crée d'abord une règle
    client.post(
        f"/api/v1/profiles/{test_profile.id}/rules",
        json={"rule_type": "DAILY_LIMIT", "max_minutes_per_day": 60, "is_active": True},
        headers=auth_headers,
    )
    response = client.get(f"/api/v1/profiles/{test_profile.id}/rules", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1

def test_delete_rule(client, auth_headers, test_profile):
    # Crée une règle
    create_resp = client.post(
        f"/api/v1/profiles/{test_profile.id}/rules",
        json={"rule_type": "DAILY_LIMIT", "max_minutes_per_day": 30, "is_active": True},
        headers=auth_headers,
    )
    rule_id = create_resp.json()["id"]
    
    # Supprime-la
    delete_resp = client.delete(f"/api/v1/profiles/{test_profile.id}/rules/{rule_id}", headers=auth_headers)
    assert delete_resp.status_code == 200
