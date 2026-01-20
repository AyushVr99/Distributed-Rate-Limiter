package com.platform.gateway.distributed_rate_limiter.util;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class KeyResolver {
    public enum Strategy {
        COMBINED,
        PRIORITY
    }

    @Value("${rate-limiter.key-strategy:PRIORITY}")
    private String keyStrategy;

    public String resolve(HttpServletRequest request) {
        Strategy strategy = Strategy.valueOf(keyStrategy.toUpperCase());

        if (strategy == Strategy.COMBINED) {
            return resolveCombined(request);
        } else {
            return resolvePriority(request);
        }
    }

    /**
     * Priority-based resolution: Use the most specific identifier available.
     * This is the recommended approach as it provides appropriate granularity
     * without being overly restrictive.
     */
    private String resolvePriority(HttpServletRequest request) {
        // Priority 1: API Key (most specific - for API clients)
        String apiKey = request.getHeader("X-API-KEY");
        if (StringUtils.hasText(apiKey)) {
            return "rate:apikey:" + apiKey.trim();
        }

        // Priority 2: User ID (for authenticated users)
        String userId = resolveUserId(request);
        if (StringUtils.hasText(userId)) {
            return "rate:user:" + userId.trim();
        }

        // Priority 3: IP Address (fallback for anonymous users)
        String clientIp = resolveClientIp(request);
        return "rate:ip:" + clientIp;
    }

    /**
     * Combined resolution: Use all three identifiers together.
     * More granular but creates many unique keys and can be overly restrictive.
     */
    private String resolveCombined(HttpServletRequest request) {
        String apiKeyHeader = request.getHeader("X-API-KEY");
        String apiKey = StringUtils.hasText(apiKeyHeader) ? apiKeyHeader.trim() : "no-api-key";

        String userIdValue = resolveUserId(request);
        String userId = StringUtils.hasText(userIdValue) ? userIdValue.trim() : "anonymous";

        String clientIpValue = resolveClientIp(request);
        String clientIp = StringUtils.hasText(clientIpValue) ? clientIpValue.trim() : "unknown";

        return "rate:apikey:" + apiKey + ":user:" + userId + ":ip:" + clientIp;
    }

    private String resolveUserId(HttpServletRequest request) {
        String headerUserId = request.getHeader("X-USER-ID");
        if (StringUtils.hasText(headerUserId)) {
            return headerUserId;
        }
        return request.getRemoteUser();
    }

    private String resolveClientIp(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (StringUtils.hasText(forwardedFor)) {
            String[] parts = forwardedFor.split(",");
            return parts[0].trim();
        }
        String realIp = request.getHeader("X-Real-IP");
        if (StringUtils.hasText(realIp)) {
            return realIp.trim();
        }
        String remoteAddr = request.getRemoteAddr();
        return StringUtils.hasText(remoteAddr) ? remoteAddr : "unknown";
    }

}
