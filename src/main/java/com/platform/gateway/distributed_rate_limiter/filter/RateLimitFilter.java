package com.platform.gateway.distributed_rate_limiter.filter;

import com.platform.gateway.distributed_rate_limiter.limiter.RateLimiterService;
import com.platform.gateway.distributed_rate_limiter.model.RateLimitResult;
import com.platform.gateway.distributed_rate_limiter.util.KeyResolver;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private final RateLimiterService limiter;
    private final KeyResolver keyResolver;

    public RateLimitFilter(RateLimiterService limiter, KeyResolver keyResolver) {
        this.limiter = limiter;
        this.keyResolver = keyResolver;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        String key = keyResolver.resolve(request);
        RateLimitResult result = limiter.isAllowed(key);

        response.setHeader("X-Rate-Limit-Remaining",
                String.valueOf(result.getRemainingTokens()));

        if (!result.isAllowed()) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write("{\"error\":\"Rate limit exceeded\"}");
            return;
        }

        filterChain.doFilter(request, response);
    }
}
