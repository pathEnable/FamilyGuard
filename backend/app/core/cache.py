import json
from functools import wraps
from typing import Callable, Any
import asyncio
from starlette.concurrency import run_in_threadpool
from fastapi.encoders import jsonable_encoder
from app.core.redis_client import redis_client
import redis.asyncio as redis

def cache_response(ttl_seconds: int = 60, key_prefix: str = "cache"):
    """
    Décorateur pour mettre en cache les réponses JSON des endpoints FastAPI.
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs) -> Any:
            # Generate a cache key based on the function name and arguments
            # Filter out non-serializable arguments like db sessions or request objects
            safe_kwargs = {k: v for k, v in kwargs.items() if isinstance(v, (int, str, bool, float))}
            key_parts = [key_prefix, func.__name__] + [str(v) for v in safe_kwargs.values()]
            for arg in args:
                if isinstance(arg, (int, str, bool, float)):
                    key_parts.append(str(arg))
                    
            cache_key = ":".join(key_parts)

            try:
                cached_data = await redis_client.get(cache_key)
                if cached_data:
                    return json.loads(cached_data)
            except redis.ConnectionError:
                pass # Proceed without cache if Redis is down

            # Execute the function
            if asyncio.iscoroutinefunction(func):
                result = await func(*args, **kwargs)
            else:
                result = await run_in_threadpool(func, *args, **kwargs)

            # If result is a dict or a Pydantic model, cache it
            try:
                data_to_cache = jsonable_encoder(result)
                await redis_client.setex(cache_key, ttl_seconds, json.dumps(data_to_cache))
            except Exception as e:
                # Silently fail if we can't serialize the response
                pass

            return result
        return wrapper
    return decorator
