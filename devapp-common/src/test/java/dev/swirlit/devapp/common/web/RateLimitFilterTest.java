package dev.swirlit.devapp.common.web;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RateLimitFilterTest {

    @Test
    void rejectsRequestsAboveConfiguredLimit() throws Exception {
        RateLimitFilter filter = new RateLimitFilter(
                true, 1, 100, Clock.fixed(Instant.parse("2026-08-27T12:00:30Z"), ZoneOffset.UTC));
        MockHttpServletRequest firstRequest = new MockHttpServletRequest("GET", "/api/users");
        firstRequest.setRemoteAddr("192.0.2.10");
        MockHttpServletResponse firstResponse = new MockHttpServletResponse();

        filter.doFilter(firstRequest, firstResponse, new MockFilterChain());

        assertEquals(200, firstResponse.getStatus());
        assertEquals("0", firstResponse.getHeader("RateLimit-Remaining"));

        MockHttpServletRequest secondRequest = new MockHttpServletRequest("GET", "/api/users");
        secondRequest.setRemoteAddr("192.0.2.10");
        MockHttpServletResponse secondResponse = new MockHttpServletResponse();
        filter.doFilter(secondRequest, secondResponse, new MockFilterChain());

        assertEquals(429, secondResponse.getStatus());
        assertEquals("30", secondResponse.getHeader("Retry-After"));
        assertTrue(secondResponse.getContentAsString().contains("Too many requests"));
    }

    @Test
    void skipsNonApiRequests() throws Exception {
        RateLimitFilter filter = new RateLimitFilter(
                true, 1, 100, Clock.fixed(Instant.parse("2026-08-27T12:00:00Z"), ZoneOffset.UTC));
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/actuator/health");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());

        assertEquals(200, response.getStatus());
        assertNull(response.getHeader("RateLimit-Limit"));
    }
}
