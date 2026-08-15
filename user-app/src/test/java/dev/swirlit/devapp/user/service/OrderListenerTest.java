package dev.swirlit.devapp.user.service;

import java.time.Instant;

import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.common.event.OrderEvent;
import dev.swirlit.devapp.common.util.Constants;
import dev.swirlit.devapp.user.domain.User;
import jakarta.persistence.EntityNotFoundException;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderListenerTest {

    @Mock
    private UserService userService;
    @Mock
    private NotificationService notificationService;
    @Mock
    private KafkaTemplate<Object, Object> kafkaTemplate;
    @InjectMocks
    private OrderListener orderListener;

    @Test
    void consumeApprovesKnownUser() {
        User user = new User("Ada Lovelace", "ada", "ada@example.test");
        when(userService.getUser(1L)).thenReturn(user);
        OrderEvent input = event(10L, 1L);

        orderListener.consume(input);

        verify(notificationService).notifyUser(user, input);
        assertPublishedStatus(10L, OrderStatus.APPROVED, "Ada Lovelace");
    }

    @Test
    void consumeRejectsMissingUser() {
        when(userService.getUser(2L)).thenThrow(new EntityNotFoundException("missing"));

        orderListener.consume(event(11L, 2L));

        assertPublishedStatus(11L, OrderStatus.REJECTED, null);
    }

    @Test
    void consumeRejectsProcessingFailure() {
        when(userService.getUser(3L)).thenThrow(new IllegalStateException("boom"));

        orderListener.consume(event(12L, 3L));

        assertPublishedStatus(12L, OrderStatus.REJECTED, null);
    }

    private void assertPublishedStatus(Long orderId, OrderStatus status, String userName) {
        ArgumentCaptor<OrderEvent> captor = ArgumentCaptor.forClass(OrderEvent.class);
        verify(kafkaTemplate).send(eq(Constants.ORDER_RESULT_TOPIC), eq(orderId.toString()), captor.capture());
        assertEquals(status, captor.getValue().status());
        assertEquals(userName, captor.getValue().userName());
    }

    private static OrderEvent event(Long orderId, Long userId) {
        return new OrderEvent(orderId, userId, 1001L, null, OrderStatus.PENDING, Instant.now());
    }
}
