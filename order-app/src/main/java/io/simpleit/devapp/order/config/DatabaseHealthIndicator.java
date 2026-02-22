package io.simpleit.devapp.order.config;

import io.simpleit.devapp.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;

import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@Component("database")
@RequiredArgsConstructor
public class DatabaseHealthIndicator implements HealthIndicator {

    private final OrderRepository orderRepository;

    @Override
    public Health health() {
        try {
            long orderCount = orderRepository.count();
            return Health.up()
                    .withDetail("orderCount", orderCount)
                    .withDetail("status", "Database connection successful")
                    .build();
        } catch (Exception e) {
            return Health.down()
                    .withDetail("error", e.getMessage())
                    .withDetail("status", "Database connection failed")
                    .build();
        }
    }
}
