package io.simpleit.devapp.order.service;

import java.util.List;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.util.Constants;
import io.simpleit.devapp.order.repository.OrderRepository;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
@RequiredArgsConstructor
public class OrderService {

        private final OrderRepository orderRepository;
        private final KafkaTemplate<String, Order> kafkaTemplate;

        public List<Order> getAllOrders() {
                log.info("Fetching orders");
                return orderRepository.findAll();
        }

        @Cacheable(value = "orders", key = "#id")
        public Order getOrderById(Long id) {
                log.info("Fetching order {}", id);
                return orderRepository.findById(id)
                        .orElseThrow(() -> new EntityNotFoundException("Order not found"));
        }

        public Order createOrder(Order order) {
                Order savedOrder = orderRepository.save(order);
                kafkaTemplate.send(Constants.ORDER_TOPIC, savedOrder);
                return savedOrder;
        }

}
