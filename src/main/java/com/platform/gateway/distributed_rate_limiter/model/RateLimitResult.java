package com.platform.gateway.distributed_rate_limiter.model;

public class RateLimitResult {

    private final boolean allowed;
    private final long remainingTokens;

    public RateLimitResult(boolean allowed, long remainingTokens) {
        this.allowed = allowed;
        this.remainingTokens = remainingTokens;
    }

    public boolean isAllowed() {
        return allowed;
    }

    public long getRemainingTokens() {
        return remainingTokens;
    }
}
