package dev.swirlit.devapp.user.service;

import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.common.event.OrderEvent;
import dev.swirlit.devapp.common.util.Constants;
import dev.swirlit.devapp.user.domain.User;
import jakarta.persistence.EntityNotFoundException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class OrderListener {

    private static final Logger log = LoggerFactory.getLogger(OrderListener.class);

    private final UserService userService;
    private final NotificationService notificationService;
    private final KafkaTemplate<Object, Object> kafkaTemplate;

    public OrderListener(
            UserService userService,
            NotificationService notificationService,
            KafkaTemplate<Object, Object> kafkaTemplate) {
        this.userService = userService;
        this.notificationService = notificationService;
        this.kafkaTemplate = kafkaTemplate;
    }

    @KafkaListener(topics = Constants.ORDER_TOPIC, groupId = "${spring.kafka.consumer.group-id}")
    public void consume(OrderEvent event) {
        OrderEvent result;
        try {
            User user = userService.getUser(event.userId());
            notificationService.notifyUser(user, event);
            result = event.withResult(user.getName(), OrderStatus.APPROVED);
        } catch (EntityNotFoundException exception) {
            log.warn("Rejecting order {} because user {} does not exist", event.orderId(), event.userId());
            result = event.withResult(null, OrderStatus.REJECTED);
        } catch (RuntimeException exception) {
            log.error("Rejecting order {} after processing failure", event.orderId(), exception);
            result = event.withResult(null, OrderStatus.REJECTED);
        }
        kafkaTemplate.send(Constants.ORDER_RESULT_TOPIC, event.orderId().toString(), result);
    }
}
