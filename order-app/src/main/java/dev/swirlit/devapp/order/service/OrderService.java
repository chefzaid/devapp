package dev.swirlit.devapp.order.service;

import java.util.List;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;

import dev.swirlit.devapp.common.domain.Order;
import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.common.util.Constants;
import dev.swirlit.devapp.order.repository.OrderRepository;
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

        @Transactional
        public Order createOrder(Order order) {
                order.setStatus(OrderStatus.PENDING);
                Order savedOrder = orderRepository.save(order);
                kafkaTemplate.send(Constants.ORDER_TOPIC, savedOrder);
                return savedOrder;
        }

}
