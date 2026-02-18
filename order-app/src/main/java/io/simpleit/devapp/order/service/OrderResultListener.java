package io.simpleit.devapp.order.service;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.common.util.Constants;
import io.simpleit.devapp.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@Profile("!test")
@Slf4j
@RequiredArgsConstructor
public class OrderResultListener {

    private final OrderRepository orderRepository;

    @KafkaListener(topics = Constants.ORDER_RESULT_TOPIC, groupId = "${spring.kafka.consumer.group-id}", containerFactory = "kafkaListenerContainerFactory")
    public void consume(Order order) {
        log.info("Received order update: {}", order);
        orderRepository.findById(order.getId()).ifPresent(existingOrder -> {
            existingOrder.setStatus(order.getStatus());
            orderRepository.save(existingOrder);
        });
    }
}
