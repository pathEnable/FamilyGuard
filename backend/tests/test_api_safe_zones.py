def test_create_safe_zone(client, auth_headers, test_profile):
    response = client.post(
        f"/api/v1/safe-zones/{test_profile.id}/safe-zones",
        headers=auth_headers,
        json={
            "name": "Home",
            "latitude": 48.8566,
            "longitude": 2.3522,
            "radius_meters": 500,
            "is_active": True
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Home"
    assert data["latitude"] == 48.8566
    assert data["radius_meters"] == 500
    assert "id" in data

def test_list_safe_zones(client, auth_headers, test_profile):
    # Create a zone first
    client.post(
        f"/api/v1/safe-zones/{test_profile.id}/safe-zones",
        headers=auth_headers,
        json={
            "name": "School",
            "latitude": 48.85,
            "longitude": 2.35,
            "radius_meters": 200,
            "is_active": True
        }
    )
    
    response = client.get(f"/api/v1/safe-zones/{test_profile.id}/safe-zones", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1

def test_update_safe_zone(client, auth_headers, test_profile):
    # Create
    create_resp = client.post(
        f"/api/v1/safe-zones/{test_profile.id}/safe-zones",
        headers=auth_headers,
        json={
            "name": "Park",
            "latitude": 48.86,
            "longitude": 2.36,
            "radius_meters": 300,
            "is_active": True
        }
    )
    zone_id = create_resp.json()["id"]
    
    # Update
    update_resp = client.put(
        f"/api/v1/safe-zones/{test_profile.id}/safe-zones/{zone_id}",
        headers=auth_headers,
        json={"name": "Grand Park", "radius_meters": 600}
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["name"] == "Grand Park"
    assert update_resp.json()["radius_meters"] == 600

def test_delete_safe_zone(client, auth_headers, test_profile):
    # Create
    create_resp = client.post(
        f"/api/v1/safe-zones/{test_profile.id}/safe-zones",
        headers=auth_headers,
        json={
            "name": "Temporary",
            "latitude": 48.87,
            "longitude": 2.37,
            "radius_meters": 100,
            "is_active": True
        }
    )
    zone_id = create_resp.json()["id"]
    
    # Delete
    delete_resp = client.delete(
        f"/api/v1/safe-zones/{test_profile.id}/safe-zones/{zone_id}",
        headers=auth_headers
    )
    assert delete_resp.status_code == 200

def test_delete_safe_zone_not_found(client, auth_headers, test_profile):
    response = client.delete(
        f"/api/v1/safe-zones/{test_profile.id}/safe-zones/9999",
        headers=auth_headers
    )
    assert response.status_code == 404
