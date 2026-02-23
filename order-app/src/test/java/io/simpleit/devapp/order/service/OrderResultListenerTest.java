package io.simpleit.devapp.order.service;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.domain.OrderStatus;
import io.simpleit.devapp.order.repository.OrderRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderResultListenerTest {

    @Mock
    private OrderRepository orderRepository;

    @InjectMocks
    private OrderResultListener orderResultListener;

    @Test
    void consume_shouldUpdateAndSave_whenOrderExists() {
        Order incoming = new Order();
        incoming.setId(1L);
        incoming.setStatus(OrderStatus.APPROVED);

        Order existing = new Order();
        existing.setId(1L);
        existing.setStatus(OrderStatus.PENDING);

        when(orderRepository.findById(1L)).thenReturn(Optional.of(existing));

        orderResultListener.consume(incoming);

        verify(orderRepository).save(existing);
    }

    @Test
    void consume_shouldNotSave_whenOrderDoesNotExist() {
        Order incoming = new Order();
        incoming.setId(404L);
        incoming.setStatus(OrderStatus.REJECTED);

        when(orderRepository.findById(404L)).thenReturn(Optional.empty());

        orderResultListener.consume(incoming);

        verify(orderRepository, never()).save(any(Order.class));
    }
}
