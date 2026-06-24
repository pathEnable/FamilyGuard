def test_create_profile(client, auth_headers):
    response = client.post(
        "/api/v1/profiles/",
        json={"name": "Alice", "age": 10},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Alice"
    assert data["age"] == 10
    assert "id" in data

def test_list_profiles(client, auth_headers, test_profile):
    response = client.get("/api/v1/profiles/", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 1
    assert data[0]["name"] == "Child Test"

def test_get_profile(client, auth_headers, test_profile):
    response = client.get(f"/api/v1/profiles/{test_profile.id}", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["id"] == test_profile.id

def test_get_profile_not_found(client, auth_headers):
    response = client.get("/api/v1/profiles/9999", headers=auth_headers)
    assert response.status_code == 404

def test_delete_profile(client, auth_headers, test_profile):
    response = client.delete(f"/api/v1/profiles/{test_profile.id}", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["status"] == "success"
