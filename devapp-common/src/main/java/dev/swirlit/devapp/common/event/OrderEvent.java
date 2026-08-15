package dev.swirlit.devapp.common.event;

import java.time.Instant;

import dev.swirlit.devapp.common.domain.OrderStatus;

public record OrderEvent(
        Long orderId,
        Long userId,
        Long productId,
        String userName,
        OrderStatus status,
        Instant occurredAt) {

    public OrderEvent withResult(String resolvedUserName, OrderStatus resolvedStatus) {
        return new OrderEvent(orderId, userId, productId, resolvedUserName, resolvedStatus, Instant.now());
    }
}
