package io.simpleit.devapp.order.config;

import io.simpleit.devapp.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;

import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.kafka.core.KafkaTemplate;
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

@Component("redis")
@RequiredArgsConstructor
class RedisHealthIndicator implements HealthIndicator {

    private final RedisConnectionFactory redisConnectionFactory;

    @Override
    public Health health() {
        try {
            var connection = redisConnectionFactory.getConnection();
            connection.ping();
            connection.close();
            return Health.up()
                    .withDetail("status", "Redis connection successful")
                    .build();
        } catch (Exception e) {
            return Health.down()
                    .withDetail("error", e.getMessage())
                    .withDetail("status", "Redis connection failed")
                    .build();
        }
    }
}

@Component("kafka")
@RequiredArgsConstructor
class KafkaHealthIndicator implements HealthIndicator {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Override
    public Health health() {
        try {
            var metrics = kafkaTemplate.metrics();
            return Health.up()
                    .withDetail("status", "Kafka connection successful")
                    .withDetail("metricsCount", metrics.size())
                    .build();
        } catch (Exception e) {
            return Health.down()
                    .withDetail("error", e.getMessage())
                    .withDetail("status", "Kafka connection failed")
                    .build();
        }
    }
}
