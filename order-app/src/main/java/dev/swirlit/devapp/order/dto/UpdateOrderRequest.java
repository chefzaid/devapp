package dev.swirlit.devapp.order.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record UpdateOrderRequest(
        @NotNull @Positive Long userId,
        @NotNull @Positive Long productId) {
}
