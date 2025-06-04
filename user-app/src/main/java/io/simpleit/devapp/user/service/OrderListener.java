package io.simpleit.devapp.user.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.domain.User;

import io.simpleit.devapp.user.service.NotificationService;

@Service
public class OrderListener {

    @Autowired
    private UserService userService;

    @Autowired
    private NotificationService notificationService;

    @KafkaListener(topics = "order_topic", groupId = "group_id", containerFactory = "kafkaListenerContainerFactory")
    public void consume(Order order) {
        // Notify the user about the order
        User user = userService.getUser(order.getUser().getId());
        if (user != null) {
            notificationService.notifyUser(user, order);
        }
    }
}