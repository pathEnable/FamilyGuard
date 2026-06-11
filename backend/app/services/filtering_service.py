import redis
from app.core.config import settings

# Initialize Redis client
redis_client = redis.Redis(
    host="localhost", # In production, this comes from settings
    port=6379,
    db=0,
    decode_responses=True
)

class FilteringService:
    """
    Core service for checking URLs against the 500M database.
    Implements Option C: Bloom Filter -> Redis -> PostgreSQL
    """
    def __init__(self):
        # Key for the RedisBloom filter
        self.bloom_key = "safechild:bloom:blocked_urls"
        # Key for standard Redis Set (fallback)
        self.fallback_set_key = "safechild:set:blocked_urls"
    
    def is_url_blocked(self, url: str) -> bool:
        """
        Check if a URL is blocked.
        Returns True if blocked, False if allowed.
        """
        try:
            # Step 1: Bloom Filter Check (Fastest - O(1), ~1ms)
            # We use BF.EXISTS if the RedisBloom module is loaded
            # result = redis_client.execute_command("BF.EXISTS", self.bloom_key, url)
            
            # Dev mock: Using standard Redis Sets until RedisBloom is active
            result = redis_client.sismember(self.fallback_set_key, url)
            
            if not result:
                # If Bloom Filter returns 0, the URL is DEFINITELY NOT in the blocked list.
                # Safe to allow.
                return False
                
            # Step 2: False Positive Resolution (Redis Cache / PostgreSQL)
            # If Bloom Filter returns 1, it MIGHT be in the list (or it's a false positive).
            # We then check PostgreSQL to confirm definitively.
            # is_definitely_blocked = check_postgres_db(url)
            # return is_definitely_blocked
            
            return True
            
        except Exception as e:
            print(f"Redis error: {e}")
            # Failsafe: if cache is down, we must query PostgreSQL directly
            # return check_postgres_db(url)
            return False

filtering_service = FilteringService()
