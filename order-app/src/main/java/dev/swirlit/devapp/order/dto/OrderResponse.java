package dev.swirlit.devapp.order.dto;

import java.time.Instant;

import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.order.domain.Order;

public record OrderResponse(
        Long id,
        Long userId,
        String userName,
        Long productId,
        OrderStatus status,
        Instant createdDate,
        Instant lastModifiedDate) {

    public static OrderResponse from(Order order) {
        return new OrderResponse(
                order.getId(), order.getUserId(), order.getUserName(), order.getProductId(), order.getStatus(),
                order.getCreatedDate(), order.getLastModifiedDate());
    }
}
