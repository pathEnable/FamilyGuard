def test_download_bloom_filter(client):
    response = client.get("/api/v1/filtering/filter.bin")
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/octet-stream"
    assert "filter.bin" in response.headers["content-disposition"]

def test_add_web_filter_rule(client, auth_headers, test_profile):
    response = client.post(
        f"/api/v1/filtering/profiles/{test_profile.id}/rules",
        headers=auth_headers,
        json={"url_pattern": "badsite.com", "rule_type": "BLACKLIST"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["url_pattern"] == "badsite.com"
    assert data["rule_type"] == "BLACKLIST"
    assert "id" in data

def test_add_invalid_rule_type(client, auth_headers, test_profile):
    response = client.post(
        f"/api/v1/filtering/profiles/{test_profile.id}/rules",
        headers=auth_headers,
        json={"url_pattern": "anothersite.com", "rule_type": "INVALID"}
    )
    assert response.status_code == 400

def test_get_web_filters(client, auth_headers, test_profile):
    # First add a rule
    client.post(
        f"/api/v1/filtering/profiles/{test_profile.id}/rules",
        headers=auth_headers,
        json={"url_pattern": "youtube.com", "rule_type": "WHITELIST"}
    )
    
    response = client.get(f"/api/v1/filtering/profiles/{test_profile.id}/rules", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert "strict_mode" in data
    assert isinstance(data["rules"], list)
    assert len(data["rules"]) >= 1

def test_delete_web_filter_rule(client, auth_headers, test_profile):
    # Add rule
    add_response = client.post(
        f"/api/v1/filtering/profiles/{test_profile.id}/rules",
        headers=auth_headers,
        json={"url_pattern": "deleteme.com", "rule_type": "BLACKLIST"}
    )
    rule_id = add_response.json()["id"]
    
    # Delete rule
    delete_response = client.delete(
        f"/api/v1/filtering/profiles/{test_profile.id}/rules/{rule_id}",
        headers=auth_headers
    )
    assert delete_response.status_code == 200
    
    # Verify deleted
    get_response = client.get(f"/api/v1/filtering/profiles/{test_profile.id}/rules", headers=auth_headers)
    rules = get_response.json()["rules"]
    assert not any(r["id"] == rule_id for r in rules)

def test_toggle_strict_mode(client, auth_headers, test_profile):
    response = client.put(
        f"/api/v1/filtering/profiles/{test_profile.id}/strict-mode",
        headers=auth_headers,
        json={"strict_mode": True}
    )
    assert response.status_code == 200
    assert response.json()["strict_mode"] is True

def test_log_blocked_url(client, auth_headers, test_profile):
    response = client.post(
        "/api/v1/filtering/log",
        headers=auth_headers,
        json={
            "profile_id": test_profile.id,
            "url": "https://malicious.com",
            "reason": "Phishing"
        }
    )
    assert response.status_code == 200
    assert response.json()["status"] == "success"

def test_check_url(client):
    response = client.post(
        "/api/v1/filtering/check",
        json={"url": "example.com"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "is_blocked" in data
