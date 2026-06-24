import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import os

# Create an in-memory SQLite database for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# We need to import our dependencies and app after setting up the DB engine
from app.core.database import Base, get_db
from app.main import app
from app.core.security import get_password_hash
from app.models import User, Profile

@pytest.fixture(scope="session", autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def db_session():
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()

@pytest.fixture(scope="function")
def client():
    def override_get_db():
        session = TestingSessionLocal()
        try:
            yield session
        finally:
            session.close()
            
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()

@pytest.fixture(scope="function")
def test_user(db_session):
    db_session.query(User).delete()
    db_session.commit()
    
    user = User(
        email="test@example.com",
        hashed_password=get_password_hash("Password123!"),
        is_active=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture(scope="function")
def test_profile(db_session, test_user):
    db_session.query(Profile).delete()
    db_session.commit()
    
    profile = Profile(
        parent_id=test_user.id,
        name="Test Child",
        age=10,
        device_id="device123",
        pairing_code="123456",
        is_active=True
    )
    db_session.add(profile)
    db_session.commit()
    db_session.refresh(profile)
    return profile

@pytest.fixture(scope="function")
def token_headers(client, test_user):
    # Log in
    response = client.post(
        "/api/v1/auth/login",
        data={"username": "test@example.com", "password": "Password123!"}
    )
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
