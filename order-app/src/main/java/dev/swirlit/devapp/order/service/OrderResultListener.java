package dev.swirlit.devapp.order.service;

import dev.swirlit.devapp.common.event.OrderEvent;
import dev.swirlit.devapp.common.util.Constants;
import dev.swirlit.devapp.order.repository.OrderRepository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderResultListener {

    private static final Logger log = LoggerFactory.getLogger(OrderResultListener.class);
    private final OrderRepository orderRepository;

    public OrderResultListener(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Transactional
    @CacheEvict(cacheNames = "orders", key = "#event.orderId()")
    @KafkaListener(topics = Constants.ORDER_RESULT_TOPIC, groupId = "${spring.kafka.consumer.group-id}")
    public void consume(OrderEvent event) {
        orderRepository.findById(event.orderId()).ifPresentOrElse(order -> {
            order.setStatus(event.status());
            order.setUserName(event.userName());
        }, () -> log.warn("Ignoring result for missing order {}", event.orderId()));
    }
}
