package com.platform.gateway.distributed_rate_limiter.limiter;

import com.platform.gateway.distributed_rate_limiter.model.RateLimitResult;

public interface RateLimiterService {
    RateLimitResult isAllowed(String key);
}
