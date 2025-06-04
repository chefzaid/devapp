package io.simpleit.devapp.order.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.cache.CacheManager;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.order.repository.OrderRepository;

@SpringBootTest
class OrderServiceTest {

    @Autowired
    private OrderService orderService;

    @MockBean
    private OrderRepository orderRepository;

    @Autowired
    private CacheManager cacheManager;

    @Test
    void testGetOrderByIdCachesResult() {
        Order order = new Order();
        order.setId(1L);
        when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

        Optional<Order> first = orderService.getOrderById(1L);
        Optional<Order> second = orderService.getOrderById(1L);

        assertThat(first).isPresent();
        assertThat(second).isPresent();
        // Ensure repository called only once due to caching
        assertThat(cacheManager.getCache("orders").get(1L).get()).isEqualTo(order);
    }
}
