"""
Test E2E : Flux d'appairage complet
1. Le parent s'inscrit et se connecte
2. Le parent crée un profil enfant
3. Le parent génère un code d'appairage
4. L'appareil enfant soumet le code et reçoit un token enfant
5. L'appareil enfant utilise le token enfant pour envoyer des stats d'usage
"""

def test_full_pairing_flow(client):
    # Étape 1 : Inscription et connexion du parent
    client.post("/api/v1/auth/register", json={"email": "parent@famille.fr", "password": "SecurePass1!"})
    
    login_resp = client.post(
        "/api/v1/auth/login",
        data={"username": "parent@famille.fr", "password": "SecurePass1!"}
    )
    assert login_resp.status_code == 200
    parent_token = login_resp.json()["access_token"]
    parent_headers = {"Authorization": f"Bearer {parent_token}"}

    # Étape 2 : Création du profil enfant
    profile_resp = client.post(
        "/api/v1/profiles/",
        json={"name": "Emma", "age": 8},
        headers=parent_headers,
    )
    assert profile_resp.status_code == 200
    profile_id = profile_resp.json()["id"]

    # Étape 3 : Génération du code d'appairage
    pairing_resp = client.post(
        f"/api/v1/profiles/{profile_id}/pairing-code",
        headers=parent_headers,
    )
    assert pairing_resp.status_code == 200
    pairing_code = pairing_resp.json()["pairing_code"]
    assert len(pairing_code) == 6
    assert pairing_code.isdigit()

    # Étape 4 : L'appareil de l'enfant soumet le code → token enfant
    pair_resp = client.post(
        "/api/v1/auth/pair-device",
        json={"pairing_code": pairing_code},
    )
    assert pair_resp.status_code == 200
    child_token = pair_resp.json()["access_token"]
    assert child_token is not None
    assert pair_resp.json()["profile"]["id"] == profile_id
    
    child_headers = {"Authorization": f"Bearer {child_token}"}

    # Étape 5 : Vérification de la protection anti-replay
    # Le code d'appairage est consommé — il ne doit plus être utilisable
    replay_resp = client.post(
        "/api/v1/auth/pair-device",
        json={"pairing_code": pairing_code},
    )
    assert replay_resp.status_code == 400, "Le code d'appairage doit être invalidé après usage"

    # Étape 6 : Le token enfant doit permettre d'accéder à la gamification
    gamification_resp = client.get(
        f"/api/v1/profiles/{profile_id}/gamification",
        headers=child_headers,
    )
    # 200 avec token enfant valide
    assert gamification_resp.status_code == 200
