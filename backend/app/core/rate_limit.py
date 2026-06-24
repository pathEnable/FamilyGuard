from fastapi import HTTPException, Request, status
from starlette.concurrency import run_in_threadpool
from functools import wraps
import asyncio
import time
import time
import redis.asyncio as redis
from app.core.redis_client import redis_client

def RateLimiter(requests: int = 5, window: int = 60):
    """
    Dépendance / Decorateur pour limiter le nombre de requêtes.
    Utilise Redis pour stocker le compte des requêtes par IP et par route.
    """
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, request: Request = None, **kwargs):
            # Try to get request object from kwargs or args
            req = request
            if req is None:
                for arg in args:
                    if isinstance(arg, Request):
                        req = arg
                        break
                if req is None:
                    for kwarg in kwargs.values():
                        if isinstance(kwarg, Request):
                            req = kwarg
                            break

            if req is None:
                # If no request object is found in the endpoint signature, we bypass
                # but ideally, rate limited endpoints should include request: Request
                return await func(*args, **kwargs)

            # Define unique key based on IP and Route
            client_ip = req.client.host if req.client else "unknown"
            route_path = req.url.path
            key = f"rate_limit:{client_ip}:{route_path}"

            try:
                # Use Redis pipeline to increment and set expire atomically
                async with redis_client.pipeline(transaction=True) as pipe:
                    pipe.incr(key)
                    pipe.expire(key, window, nx=True) # set expire only if key doesn't have one
                    results = await pipe.execute()
                    
                    current_requests = results[0]

                if current_requests > requests:
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail="Trop de requêtes. Veuillez réessayer plus tard."
                    )
            except redis.ConnectionError:
                # If redis is down, we can either block or allow. We choose to allow to prevent full outage.
                pass

            if asyncio.iscoroutinefunction(func):
                return await func(*args, request=req, **kwargs) if request else await func(*args, **kwargs)
            else:
                return await run_in_threadpool(func, *args, request=req, **kwargs) if request else await run_in_threadpool(func, *args, **kwargs)
        return wrapper
    return decorator
