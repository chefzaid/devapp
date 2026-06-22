package dev.swirlit.devapp.order.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import dev.swirlit.devapp.common.domain.Order;
import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.common.domain.User;
import dev.swirlit.devapp.order.config.DatabaseHealthIndicator;
import dev.swirlit.devapp.order.service.OrderService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(controllers = OrderController.class,
    excludeAutoConfiguration = {
        org.springframework.boot.security.oauth2.server.resource.autoconfigure.OAuth2ResourceServerAutoConfiguration.class,
        org.springframework.boot.kafka.autoconfigure.KafkaAutoConfiguration.class,
        org.springframework.boot.data.redis.autoconfigure.DataRedisAutoConfiguration.class
    })
@ActiveProfiles("test")
@TestPropertySource(properties = {
    "spring.kafka.bootstrap-servers=localhost:9092",
    "spring.data.redis.host=localhost",
    "spring.data.redis.port=6379"
})
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private OrderService orderService;

    @MockitoBean
    private DatabaseHealthIndicator databaseHealthIndicator;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    // Boot 4 auto-configures a Jackson 3 mapper; use a local Jackson 2 mapper for request-body serialization.
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void getAllOrders_ShouldReturnOrderList() throws Exception {
        // Given
        User user = new User();
        user.setId(1L);
        user.setName("John Doe");
        
        Order order1 = new Order();
        order1.setId(1L);
        order1.setProductId(101L);
        order1.setStatus(OrderStatus.PENDING);
        order1.setUser(user);
        
        Order order2 = new Order();
        order2.setId(2L);
        order2.setProductId(102L);
        order2.setStatus(OrderStatus.COMPLETED);
        order2.setUser(user);
        
        List<Order> orders = Arrays.asList(order1, order2);
        when(orderService.getAllOrders()).thenReturn(orders);

        // When & Then
        mockMvc.perform(get("/api/orders").with(jwt()))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].productId").value(101))
                .andExpect(jsonPath("$[0].status").value("PENDING"))
                .andExpect(jsonPath("$[1].id").value(2))
                .andExpect(jsonPath("$[1].productId").value(102))
                .andExpect(jsonPath("$[1].status").value("COMPLETED"));
    }

    @Test
    void getOrderById_ShouldReturnOrder() throws Exception {
        // Given
        User user = new User();
        user.setId(1L);
        user.setName("John Doe");
        
        Order order = new Order();
        order.setId(1L);
        order.setProductId(101L);
        order.setStatus(OrderStatus.PENDING);
        order.setUser(user);
        
        when(orderService.getOrderById(1L)).thenReturn(order);

        // When & Then
        mockMvc.perform(get("/api/orders/1").with(jwt()))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.productId").value(101))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void createOrder_ShouldReturnCreatedOrder() throws Exception {
        // Given
        User user = new User();
        user.setId(1L);
        user.setName("John Doe");

        Order inputOrder = new Order();
        inputOrder.setProductId(101L);
        inputOrder.setUser(user);

        Order savedOrder = new Order();
        savedOrder.setId(1L);
        savedOrder.setProductId(101L);
        savedOrder.setStatus(OrderStatus.PENDING);
        savedOrder.setUser(user);

        when(orderService.createOrder(any(Order.class))).thenReturn(savedOrder);

        // When & Then
        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(inputOrder))
                .with(jwt()))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.productId").value(101))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }
}
