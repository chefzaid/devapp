package dev.swirlit.devapp.order.service;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;

import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.common.event.OrderEvent;
import dev.swirlit.devapp.common.util.Constants;
import dev.swirlit.devapp.order.domain.Order;
import dev.swirlit.devapp.order.dto.CreateOrderRequest;
import dev.swirlit.devapp.order.repository.OrderRepository;
import jakarta.persistence.EntityNotFoundException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Sort;
import org.springframework.kafka.core.KafkaTemplate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;
    @Mock
    private KafkaTemplate<Object, Object> kafkaTemplate;
    private OrderService orderService;

    @BeforeEach
    void setUp() {
        orderService = new OrderService(orderRepository, kafkaTemplate, true);
    }

    @Test
    void getAllOrdersSortsNewestFirst() {
        Order order = order(1L);
        when(orderRepository.findAll(any(Sort.class))).thenReturn(List.of(order));

        assertEquals(List.of(order), orderService.getAllOrders());
    }

    @Test
    void getOrderReturnsOrder() {
        Order order = order(1L);
        when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

        assertEquals(order, orderService.getOrderById(1L));
    }

    @Test
    void createOrderSavesPendingOrderAndPublishesEvent() {
        when(orderRepository.save(any(Order.class))).thenAnswer(invocation -> {
            Order value = invocation.getArgument(0);
            value.setId(7L);
            return value;
        });
        when(kafkaTemplate.send(eq(Constants.ORDER_TOPIC), eq("7"), any(OrderEvent.class)))
                .thenReturn(new CompletableFuture<>());

        Order result = orderService.createOrder(new CreateOrderRequest(2L, 2001L));

        assertEquals(OrderStatus.PENDING, result.getStatus());
        ArgumentCaptor<OrderEvent> event = ArgumentCaptor.forClass(OrderEvent.class);
        verify(kafkaTemplate).send(eq(Constants.ORDER_TOPIC), eq("7"), event.capture());
        assertEquals(2L, event.getValue().userId());
    }

    @Test
    void createOrderSkipsKafkaWhenMessagingIsDisabled() {
        orderService = new OrderService(orderRepository, kafkaTemplate, false);
        when(orderRepository.save(any(Order.class))).thenAnswer(invocation -> invocation.getArgument(0));

        orderService.createOrder(new CreateOrderRequest(1L, 1001L));

        verify(kafkaTemplate, never()).send(any(), any(), any());
    }

    @Test
    void getOrderRejectsUnknownId() {
        when(orderRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(EntityNotFoundException.class, () -> orderService.getOrderById(99L));
    }

    private static Order order(Long id) {
        Order order = new Order(1L, 1001L);
        order.setId(id);
        return order;
    }
}
