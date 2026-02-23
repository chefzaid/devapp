package io.simpleit.devapp.user.service;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.domain.OrderStatus;
import io.simpleit.devapp.common.domain.User;
import io.simpleit.devapp.common.util.Constants;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderListenerTest {

    @Mock
    private UserService userService;
    @Mock
    private NotificationService notificationService;
    @Mock
    private KafkaTemplate<String, Order> kafkaTemplate;

    @InjectMocks
    private OrderListener orderListener;

    @Test
    void consume_shouldApproveAndNotify_whenUserExists() {
        User user = new User();
        user.setId(1L);
        user.setName("Alice");

        Order order = new Order();
        order.setId(10L);
        order.setUser(user);

        when(userService.getUser(1L)).thenReturn(user);

        orderListener.consume(order);

        assertEquals(OrderStatus.APPROVED, order.getStatus());
        verify(notificationService).notifyUser(user, order);
        verify(kafkaTemplate).send(Constants.ORDER_RESULT_TOPIC, order);
    }

    @Test
    void consume_shouldReject_whenUserInfoMissing() {
        Order order = new Order();
        order.setId(11L);
        order.setUser(null);

        orderListener.consume(order);

        assertEquals(OrderStatus.REJECTED, order.getStatus());
        verify(notificationService, never()).notifyUser(any(), any());
        verify(kafkaTemplate).send(Constants.ORDER_RESULT_TOPIC, order);
    }

    @Test
    void consume_shouldReject_whenUserNotFound() {
        User user = new User();
        user.setId(2L);

        Order order = new Order();
        order.setId(12L);
        order.setUser(user);

        when(userService.getUser(2L)).thenThrow(new EntityNotFoundException("User not found"));

        orderListener.consume(order);

        assertEquals(OrderStatus.REJECTED, order.getStatus());
        verify(kafkaTemplate).send(Constants.ORDER_RESULT_TOPIC, order);
    }

    @Test
    void consume_shouldReject_whenUnexpectedErrorOccurs() {
        User user = new User();
        user.setId(3L);

        Order order = new Order();
        order.setId(13L);
        order.setUser(user);

        when(userService.getUser(3L)).thenThrow(new RuntimeException("boom"));

        orderListener.consume(order);

        assertEquals(OrderStatus.REJECTED, order.getStatus());
        verify(kafkaTemplate).send(Constants.ORDER_RESULT_TOPIC, order);
    }
}
