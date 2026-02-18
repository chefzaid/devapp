package io.simpleit.devapp.user.service;

import org.springframework.context.annotation.Profile;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.domain.OrderStatus;
import io.simpleit.devapp.common.domain.User;
import io.simpleit.devapp.common.util.Constants;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@Profile("!test")
@Slf4j
@RequiredArgsConstructor
public class OrderListener {

    private final UserService userService;
    private final NotificationService notificationService;
    private final KafkaTemplate<String, Order> kafkaTemplate;

    @KafkaListener(topics = Constants.ORDER_TOPIC, groupId = "${spring.kafka.consumer.group-id}", containerFactory = "kafkaListenerContainerFactory")
    public void consume(Order order) {
        log.info("Processing order: {}", order);
        try {
            if (order.getUser() != null && order.getUser().getId() != null) {
                 User user = userService.getUser(order.getUser().getId());
                 // Perform further validation if needed (e.g. credit check)
                 order.setStatus(OrderStatus.APPROVED);
                 notificationService.notifyUser(user, order);
            } else {
                 log.warn("Order has no user information");
                 order.setStatus(OrderStatus.REJECTED);
            }
        } catch (EntityNotFoundException e) {
            log.warn("User not found for order: {}", order.getId());
            order.setStatus(OrderStatus.REJECTED);
        } catch (Exception e) {
            log.error("Error processing order: {}", order.getId(), e);
            order.setStatus(OrderStatus.REJECTED);
        }

        kafkaTemplate.send(Constants.ORDER_RESULT_TOPIC, order);
    }
}
