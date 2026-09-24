package dev.swirlit.devapp.common.config;

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
    NewTopics applicationTopics(
            @Value("${app.messaging.topics.order:order_topic}") String orderTopic,
            @Value("${app.messaging.topics.result:order_result_topic}") String resultTopic) {
        return new NewTopics(
                TopicBuilder.name(orderTopic).partitions(3).build(),
                TopicBuilder.name(resultTopic).partitions(3).build(),
                TopicBuilder.name(orderTopic + ".DLT").partitions(3).build(),
                TopicBuilder.name(resultTopic + ".DLT").partitions(3).build());
    }

    @Bean
    DefaultErrorHandler kafkaErrorHandler(
            KafkaTemplate<Object, Object> kafkaTemplate,
            @Value("${app.messaging.retry.interval:1s}") java.time.Duration retryInterval,
            @Value("${app.messaging.retry.max-attempts:4}") long maxAttempts) {
        DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(
                kafkaTemplate,
                (consumerRecord, exception) -> new TopicPartition(consumerRecord.topic() + ".DLT", -1));
        recoverer.setFailIfSendResultIsError(true);
        DefaultErrorHandler handler = new DefaultErrorHandler(
                recoverer,
                new FixedBackOff(retryInterval.toMillis(), Math.max(0, maxAttempts - 1)));
        handler.addNotRetryableExceptions(IllegalArgumentException.class);
        return handler;
    }
}
