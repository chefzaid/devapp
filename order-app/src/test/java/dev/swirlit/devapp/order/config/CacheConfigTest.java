package dev.swirlit.devapp.order.config;

import dev.swirlit.devapp.common.domain.OrderStatus;
import dev.swirlit.devapp.order.domain.Order;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

class CacheConfigTest {

    @Test
    void cacheValuesRetainTheirOrderType() {
        Order order = new Order(17L, 2501L);
        order.setId(23L);

        var serialization = CacheConfig.cacheConfiguration(JsonMapper.builder().findAndAddModules().build())
                .getValueSerializationPair();

        Order restored = assertInstanceOf(Order.class, serialization.read(serialization.write(order)));
        assertEquals(23L, restored.getId());
        assertEquals(OrderStatus.PENDING, restored.getStatus());
    }
}
