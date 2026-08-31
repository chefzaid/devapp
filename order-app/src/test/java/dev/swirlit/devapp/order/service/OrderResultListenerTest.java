package dev.swirlit.devapp.order.service;

import java.time.Instant;
import java.util.Optional;

import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.common.event.OrderEvent;
import dev.swirlit.devapp.order.domain.Order;
import dev.swirlit.devapp.order.repository.OrderRepository;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderResultListenerTest {

    @Mock
    private OrderRepository orderRepository;
    @InjectMocks
    private OrderResultListener orderResultListener;

    @Test
    void consumeUpdatesExistingOrder() {
        Order existing = new Order(1L, 1001L);
        existing.setId(1L);
        when(orderRepository.findById(1L)).thenReturn(Optional.of(existing));

        orderResultListener.consume(event(1L, OrderStatus.APPROVED, "Ada Lovelace"));

        assertEquals(OrderStatus.APPROVED, existing.getStatus());
        assertEquals("Ada Lovelace", existing.getUserName());
    }

    @Test
    void consumeIgnoresUnknownOrder() {
        when(orderRepository.findById(404L)).thenReturn(Optional.empty());

        assertThrows(jakarta.persistence.EntityNotFoundException.class,
                () -> orderResultListener.consume(event(404L, OrderStatus.REJECTED, null)));

        verify(orderRepository).findById(404L);
    }

    @Test
    void consumeRejectsMismatchedOrderIdentity() {
        Order existing = new Order(2L, 1001L);
        existing.setId(1L);
        when(orderRepository.findById(1L)).thenReturn(Optional.of(existing));

        assertThrows(IllegalArgumentException.class,
                () -> orderResultListener.consume(event(1L, OrderStatus.APPROVED, "Ada Lovelace")));
        assertEquals(OrderStatus.PENDING, existing.getStatus());
    }

    @Test
    void consumeIsIdempotentForDuplicateResult() {
        Order existing = new Order(1L, 1001L);
        existing.setId(1L);
        existing.setStatus(OrderStatus.APPROVED);
        existing.setUserName("Ada Lovelace");
        when(orderRepository.findById(1L)).thenReturn(Optional.of(existing));

        orderResultListener.consume(event(1L, OrderStatus.APPROVED, "Ada Lovelace"));

        assertEquals(OrderStatus.APPROVED, existing.getStatus());
    }

    private static OrderEvent event(Long orderId, OrderStatus status, String userName) {
        return new OrderEvent(orderId, 1L, 1001L, userName, status, Instant.now());
    }
}
