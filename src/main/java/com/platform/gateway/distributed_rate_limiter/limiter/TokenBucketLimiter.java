package com.platform.gateway.distributed_rate_limiter.limiter;

import com.platform.gateway.distributed_rate_limiter.model.RateLimitResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class TokenBucketLimiter implements RateLimiterService {

    private final StringRedisTemplate redisTemplate;
    private final DefaultRedisScript<List<Long>> script;

    @Value("${rate-limiter.capacity}")
    private int capacity;

    @Value("${rate-limiter.refill-rate}")
    private int refillRate;

    public TokenBucketLimiter(
            StringRedisTemplate redisTemplate,
            DefaultRedisScript<List<Long>> script
    ) {
        this.redisTemplate = redisTemplate;
        this.script = script;
    }

    @Override
    public RateLimitResult isAllowed(String key) {
        if (capacity <= 0 || refillRate <= 0) {
            return new RateLimitResult(false, 0);
        }

        long now = System.currentTimeMillis();

        List<Long> result = redisTemplate.execute(
                script,
                List.of(key),
                String.valueOf(capacity),
                String.valueOf(refillRate),
                String.valueOf(now)
        );

        if (result == null || result.size() < 2) {
            return new RateLimitResult(false, 0);
        }

        Long allowedFlag = result.get(0);
        Long remaining = result.get(1);
        boolean allowed = allowedFlag != null && allowedFlag == 1;
        long safeRemaining = remaining == null ? 0 : remaining;

        return new RateLimitResult(allowed, safeRemaining);
    }
}
