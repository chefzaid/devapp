package dev.swirlit.devapp.user.config;

import dev.swirlit.devapp.user.domain.User;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

class CacheConfigTest {

    @Test
    void cacheValuesRetainTheirUserType() {
        User user = new User("Grace Hopper", "grace", "grace@example.test");
        user.setId(17L);

        var serialization = CacheConfig.cacheConfiguration(JsonMapper.builder().findAndAddModules().build())
                .getValueSerializationPair();

        User restored = assertInstanceOf(User.class, serialization.read(serialization.write(user)));
        assertEquals(17L, restored.getId());
        assertEquals("grace", restored.getUsername());
    }
}
