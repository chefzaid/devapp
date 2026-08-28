package dev.swirlit.devapp.common.config;

import dev.swirlit.devapp.common.util.Constants;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.KafkaAdmin.NewTopics;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;
import org.apache.kafka.common.TopicPartition;

@Configuration(proxyBeanMethods = false)
@ConditionalOnProperty(name = "app.messaging.enabled", havingValue = "true")
public class KafkaReliabilityConfig {

    @Bean
    NewTopics applicationTopics() {
        return new NewTopics(
                TopicBuilder.name(Constants.ORDER_TOPIC).partitions(3).build(),
                TopicBuilder.name(Constants.ORDER_RESULT_TOPIC).partitions(3).build(),
                TopicBuilder.name(Constants.ORDER_TOPIC + ".DLT").partitions(3).build(),
                TopicBuilder.name(Constants.ORDER_RESULT_TOPIC + ".DLT").partitions(3).build());
    }

    @Bean
    DefaultErrorHandler kafkaErrorHandler(
            KafkaTemplate<Object, Object> kafkaTemplate,
            @Value("${app.messaging.retry.interval:1s}") java.time.Duration retryInterval,
            @Value("${app.messaging.retry.max-attempts:4}") long maxAttempts) {
        DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(
                kafkaTemplate,
                (record, exception) -> new TopicPartition(record.topic() + ".DLT", -1));
        recoverer.setFailIfSendResultIsError(true);
        DefaultErrorHandler handler = new DefaultErrorHandler(
                recoverer,
                new FixedBackOff(retryInterval.toMillis(), Math.max(0, maxAttempts - 1)));
        handler.addNotRetryableExceptions(IllegalArgumentException.class);
        return handler;
    }
}
