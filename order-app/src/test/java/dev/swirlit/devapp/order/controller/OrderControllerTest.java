package dev.swirlit.devapp.order.controller;

import java.util.List;

import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.common.exception.GlobalExceptionHandler;
import dev.swirlit.devapp.order.domain.Order;
import dev.swirlit.devapp.order.dto.CreateOrderRequest;
import dev.swirlit.devapp.order.service.OrderService;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.CacheManager;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(OrderController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler.class)
@TestPropertySource(properties = "app.security.enabled=false")
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private OrderService orderService;

    @MockitoBean
    private CacheManager cacheManager;

    @Test
    void getAllOrdersReturnsOrders() throws Exception {
        when(orderService.getAllOrders(100)).thenReturn(List.of(
                order(2L, 2L, "Grace Hopper", 1002L, OrderStatus.COMPLETED),
                order(1L, 1L, "Ada Lovelace", 1001L, OrderStatus.APPROVED)));

        mockMvc.perform(get("/api/orders"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].userName").value("Grace Hopper"))
                .andExpect(jsonPath("$[1].status").value("APPROVED"))
                .andExpect(jsonPath("$[0].createdBy").doesNotExist())
                .andExpect(jsonPath("$[0].version").doesNotExist());
    }

    @Test
    void getOrderReturnsOrder() throws Exception {
        when(orderService.getOrderById(1L))
                .thenReturn(order(1L, 1L, "Ada Lovelace", 1001L, OrderStatus.APPROVED));

        mockMvc.perform(get("/api/orders/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.productId").value(1001))
                .andExpect(jsonPath("$.userId").value(1));
    }

    @Test
    void createOrderValidatesAndReturnsLocation() throws Exception {
        Order created = order(4L, 2L, null, 2001L, OrderStatus.PENDING);
        when(orderService.createOrder(any(CreateOrderRequest.class))).thenReturn(created);

        mockMvc.perform(post("/api/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":2,\"productId\":2001}"))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/api/orders/4"))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void createOrderRejectsNonPositiveIdentifiers() throws Exception {
        mockMvc.perform(post("/api/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":0,\"productId\":-1}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.title").value("Validation failed"));
    }

    @Test
    void rejectsInvalidListLimit() throws Exception {
        mockMvc.perform(get("/api/orders").param("limit", "0"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.violations.limit").exists());
    }

    @Test
    void rejectsNonPositiveId() throws Exception {
        mockMvc.perform(get("/api/orders/-1"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.title").value("Validation failed"));
    }

    private static Order order(Long id, Long userId, String userName, Long productId, OrderStatus status) {
        Order order = new Order(userId, productId);
        order.setId(id);
        order.setUserName(userName);
        order.setStatus(status);
        return order;
    }
}
