package io.simpleit.devapp.order_app.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.util.Constants;
import io.simpleit.devapp.order_app.repository.OrderRepository;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
public class OrderService {

	@Autowired
	private OrderRepository orderRepository;
	@Autowired
	private KafkaTemplate<String, Order> kafkaTemplate;

	public List<Order> getAllOrders() {
		log.info("Fetching orders");
		return orderRepository.findAll();
	}

	public Order createOrder(Order order) {
		Order savedOrder = orderRepository.save(order);
		kafkaTemplate.send(Constants.ORDER_TOPIC, savedOrder);
		return savedOrder;
	}

}
