package dev.swirlit.devapp.order.service;

import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.common.event.OrderEvent;
import dev.swirlit.devapp.common.util.Constants;
import dev.swirlit.devapp.order.repository.OrderRepository;
import jakarta.persistence.EntityNotFoundException;

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
        validateResult(event);
        var order = orderRepository.findById(event.orderId())
                .orElseThrow(() -> new EntityNotFoundException("Order %d was not found".formatted(event.orderId())));
        if (!order.getUserId().equals(event.userId()) || !order.getProductId().equals(event.productId())) {
            throw new IllegalArgumentException("Order result does not match the persisted order");
        }
        if (order.getStatus() == event.status()) {
            log.debug("Ignoring duplicate {} result for order {}", event.status(), event.orderId());
            return;
        }
        if (order.getStatus() != OrderStatus.PENDING) {
            throw new IllegalArgumentException("Order %d is already %s".formatted(event.orderId(), order.getStatus()));
        }
        order.setStatus(event.status());
        order.setUserName(event.userName());
    }

    private static void validateResult(OrderEvent event) {
        if (event == null || event.orderId() == null || event.userId() == null || event.productId() == null) {
            throw new IllegalArgumentException("Order result identifiers are required");
        }
        if (event.status() != OrderStatus.APPROVED && event.status() != OrderStatus.REJECTED) {
            throw new IllegalArgumentException("Order result must be APPROVED or REJECTED");
        }
    }
}
