package io.simpleit.devapp.user.config;

import io.simpleit.devapp.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;

import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@Component("database")
@RequiredArgsConstructor
public class DatabaseHealthIndicator implements HealthIndicator {

    private final UserRepository userRepository;

    @Override
    public Health health() {
        try {
            long userCount = userRepository.count();
            return Health.up()
                    .withDetail("userCount", userCount)
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
