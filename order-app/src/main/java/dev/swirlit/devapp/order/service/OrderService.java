package dev.swirlit.devapp.order.service;

import java.time.Instant;
import java.util.List;

import dev.swirlit.devapp.common.event.OrderEvent;
import dev.swirlit.devapp.common.util.Constants;
import dev.swirlit.devapp.order.domain.Order;
import dev.swirlit.devapp.order.dto.CreateOrderRequest;
import dev.swirlit.devapp.order.repository.OrderRepository;
import jakarta.persistence.EntityNotFoundException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Sort;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderService {

    private static final Logger log = LoggerFactory.getLogger(OrderService.class);

    private final OrderRepository orderRepository;
    private final KafkaTemplate<Object, Object> kafkaTemplate;
    private final boolean messagingEnabled;

    public OrderService(
            OrderRepository orderRepository,
            KafkaTemplate<Object, Object> kafkaTemplate,
            @Value("${app.messaging.enabled:false}") boolean messagingEnabled) {
        this.orderRepository = orderRepository;
        this.kafkaTemplate = kafkaTemplate;
        this.messagingEnabled = messagingEnabled;
    }

    @Transactional(readOnly = true)
    public List<Order> getAllOrders() {
        return orderRepository.findAll(Sort.by(Sort.Direction.DESC, "id"));
    }

    @Transactional(readOnly = true)
    @Cacheable(cacheNames = "orders", key = "#id")
    public Order getOrderById(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Order %d was not found".formatted(id)));
    }

    @Transactional
    @CacheEvict(cacheNames = "orders", allEntries = true)
    public Order createOrder(CreateOrderRequest request) {
        Order saved = orderRepository.save(new Order(request.userId(), request.productId()));
        if (messagingEnabled) {
            OrderEvent event = new OrderEvent(
                    saved.getId(), saved.getUserId(), saved.getProductId(), null, saved.getStatus(), Instant.now());
            kafkaTemplate.send(Constants.ORDER_TOPIC, saved.getId().toString(), event)
                    .whenComplete((result, error) -> {
                        if (error == null) {
                            log.info("Published order event id={} partition={}", saved.getId(), result.getRecordMetadata().partition());
                        } else {
                            log.error("Could not publish order event id={}", saved.getId(), error);
                        }
                    });
        }
        return saved;
    }
}
