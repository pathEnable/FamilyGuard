import redis.asyncio as redis
from app.core.config import settings

# Global redis client instance
# Ex: redis://localhost:6379 or redis://:password@host:port/db
redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)

async def get_redis():
    """
    Dependency to get the redis client.
    Can also be imported directly to be used outside of FastAPI routes.
    """
    return redis_client
