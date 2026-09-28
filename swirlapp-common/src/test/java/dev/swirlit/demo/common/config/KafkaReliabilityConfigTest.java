package dev.swirlit.demo.common.config;

import java.util.Set;
import java.util.Collection;
import java.util.stream.Collectors;

import org.apache.kafka.clients.admin.NewTopic;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertEquals;

class KafkaReliabilityConfigTest {
    @Test
    void topicsAndDeadLettersStayInTheSelectedEnvironment() {
        var topics = new KafkaReliabilityConfig().applicationTopics("swirl-demo-app.int.order_topic", "swirl-demo-app.int.order_result_topic");
        Collection<NewTopic> declared = ReflectionTestUtils.invokeMethod(topics, "getNewTopics");
        assertEquals(Set.of("swirl-demo-app.int.order_topic", "swirl-demo-app.int.order_result_topic",
                "swirl-demo-app.int.order_topic.DLT", "swirl-demo-app.int.order_result_topic.DLT"),
                declared.stream().map(NewTopic::name).collect(Collectors.toSet()));
    }
}
