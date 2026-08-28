package dev.swirlit.devapp.common.web;

import java.io.IOException;
import java.security.Principal;
import java.time.Clock;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@Order(Ordered.LOWEST_PRECEDENCE - 10)
public class RateLimitFilter extends OncePerRequestFilter {

    private static final int WINDOW_SECONDS = 60;
    private static final String OVERFLOW_CLIENT = "__overflow__";

    private final boolean enabled;
    private final int requestsPerMinute;
    private final int maxTrackedClients;
    private final Clock clock;
    private final ConcurrentHashMap<String, ClientWindow> clients = new ConcurrentHashMap<>();
    private final AtomicInteger cleanupCounter = new AtomicInteger();

    @Autowired
    public RateLimitFilter(
            @Value("${app.rate-limit.enabled:false}") boolean enabled,
            @Value("${app.rate-limit.requests-per-minute:120}") int requestsPerMinute,
            @Value("${app.rate-limit.max-tracked-clients:10000}") int maxTrackedClients) {
        this(enabled, requestsPerMinute, maxTrackedClients, Clock.systemUTC());
    }

    RateLimitFilter(boolean enabled, int requestsPerMinute, int maxTrackedClients, Clock clock) {
        this.enabled = enabled;
        this.requestsPerMinute = Math.max(1, requestsPerMinute);
        this.maxTrackedClients = Math.max(100, maxTrackedClients);
        this.clock = clock;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return !enabled
                || "OPTIONS".equals(request.getMethod())
                || !path.startsWith("/api/")
                || path.endsWith("/openapi")
                || path.startsWith("/api/docs")
                || path.startsWith("/api/swagger-ui");
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        long epochSecond = clock.instant().getEpochSecond();
        long window = epochSecond / WINDOW_SECONDS;
        String client = clientKey(request);
        if (clients.size() >= maxTrackedClients && !clients.containsKey(client)) {
            clients.entrySet().removeIf(entry -> entry.getValue().window() < window);
            if (clients.size() >= maxTrackedClients) {
                client = OVERFLOW_CLIENT;
            }
        }

        ClientWindow usage = clients.compute(client, (key, current) -> {
            if (current == null || current.window() != window) {
                return new ClientWindow(window, new AtomicInteger(1));
            }
            current.requests().incrementAndGet();
            return current;
        });

        if ((cleanupCounter.incrementAndGet() & 1023) == 0) {
            clients.entrySet().removeIf(entry -> entry.getValue().window() < window);
        }

        int used = usage.requests().get();
        long reset = WINDOW_SECONDS - (epochSecond % WINDOW_SECONDS);
        response.setHeader("RateLimit-Limit", Integer.toString(requestsPerMinute));
        response.setHeader("RateLimit-Remaining", Integer.toString(Math.max(0, requestsPerMinute - used)));
        response.setHeader("RateLimit-Reset", Long.toString(reset));

        if (used > requestsPerMinute) {
            response.setStatus(429);
            response.setHeader("Retry-After", Long.toString(reset));
            response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
            String requestId = MDC.get("requestId");
            String requestIdProperty = requestId == null ? "" : ",\"requestId\":\"" + requestId + "\"";
            response.getWriter().write("{\"type\":\"https://devapp.swirlit.dev/problems/429\","
                    + "\"title\":\"Too many requests\",\"status\":429,"
                    + "\"detail\":\"Request limit exceeded; retry after the indicated delay\""
                    + requestIdProperty + "}");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private static String clientKey(HttpServletRequest request) {
        Principal principal = request.getUserPrincipal();
        return principal == null ? "ip:" + request.getRemoteAddr() : "user:" + principal.getName();
    }

    private record ClientWindow(long window, AtomicInteger requests) {
    }
}
