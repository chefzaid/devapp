package dev.swirlit.devapp.common.web;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

class RequestIdFilterTest {

    private final RequestIdFilter filter = new RequestIdFilter();

    @Test
    void preservesSafeRequestId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/users");
        request.addHeader(RequestIdFilter.HEADER_NAME, "trace-123");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());

        assertEquals("trace-123", response.getHeader(RequestIdFilter.HEADER_NAME));
    }

    @Test
    void replacesUnsafeRequestId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/users");
        request.addHeader(RequestIdFilter.HEADER_NAME, "bad request id\n");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());

        String generated = response.getHeader(RequestIdFilter.HEADER_NAME);
        assertNotNull(generated);
        assertNotEquals("bad request id\n", generated);
    }
}
