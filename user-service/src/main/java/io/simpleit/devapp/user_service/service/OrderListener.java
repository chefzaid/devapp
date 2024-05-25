package io.simpleit.devapp.user_service.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.domain.User;

@Service
public class OrderListener {

	@Autowired
    private UserService userService;

    @KafkaListener(topics = "order_topic", groupId = "group_id", containerFactory = "kafkaListenerContainerFactory")
    public void consume(Order order) {
        // Notify the user about the order
    	User user = userService.getUser(order.getUser().getId());
    	if (user != null) {
    		System.out.println("Notifying user " + user.getName() + " about order " + order.getId());
            // TODO: Add your notification logic here
    	}
    }
}