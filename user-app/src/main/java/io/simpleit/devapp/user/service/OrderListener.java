package io.simpleit.devapp.user.service;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.domain.User;


@Service
public class OrderListener {

    private final UserService userService;
    private final NotificationService notificationService;

    public OrderListener(UserService userService, NotificationService notificationService) {
        this.userService = userService;
        this.notificationService = notificationService;
    }

    @KafkaListener(topics = "order_topic", groupId = "group_id", containerFactory = "kafkaListenerContainerFactory")
    public void consume(Order order) {
        User user = userService.getUser(order.getUser().getId());
        notificationService.notifyUser(user, order);
    }
}