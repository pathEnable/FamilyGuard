from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.config import settings
from app.core.database import Base, engine
from app.core import firebase
from app.api import filtering, auth, profiles, time_rules, sos, ws, gamification, safe_zones, location, reports
from app.services.scheduler import start_scheduler, stop_scheduler

# Initialize DB models
Base.metadata.create_all(bind=engine)

# Initialize Firebase Admin
firebase.init_firebase()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start background scheduler on startup, stop on shutdown."""
    start_scheduler()
    yield
    stop_scheduler()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.ALLOW_ALL_CORS else settings.CORS_ORIGINS,
    allow_credentials=not settings.ALLOW_ALL_CORS, # allow_credentials=True n'est pas autorisé avec allow_origins=["*"]
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["Authentication"])
app.include_router(profiles.router, prefix=f"{settings.API_V1_STR}/profiles", tags=["Profiles"])
app.include_router(filtering.router, prefix=f"{settings.API_V1_STR}/filtering", tags=["Filtering"])
app.include_router(time_rules.router, prefix=f"{settings.API_V1_STR}/profiles", tags=["Time Rules"])
app.include_router(sos.router, prefix=f"{settings.API_V1_STR}/profiles", tags=["SOS"])
app.include_router(gamification.router, prefix=f"{settings.API_V1_STR}/profiles", tags=["Gamification"])
app.include_router(safe_zones.router, prefix=f"{settings.API_V1_STR}/safe-zones", tags=["Safe Zones"])
app.include_router(location.router, prefix=f"{settings.API_V1_STR}/profiles", tags=["Location"])
app.include_router(reports.router, prefix=f"{settings.API_V1_STR}/reports", tags=["Reports"])
app.include_router(ws.router, prefix=f"{settings.API_V1_STR}/ws", tags=["WebSockets"])

@app.get("/")
def root():
    return {"message": "Welcome to SafeChild API"}
