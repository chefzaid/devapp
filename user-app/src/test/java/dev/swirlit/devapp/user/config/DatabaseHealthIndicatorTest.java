package dev.swirlit.devapp.user.config;

import dev.swirlit.devapp.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.Status;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DatabaseHealthIndicatorTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private DatabaseHealthIndicator databaseHealthIndicator;

    @Test
    void health_shouldReturnUp_whenRepositorySucceeds() {
        when(userRepository.count()).thenReturn(3L);

        Health health = databaseHealthIndicator.health();

        assertEquals(Status.UP, health.getStatus());
        assertEquals(3L, health.getDetails().get("userCount"));
    }

    @Test
    void health_shouldReturnDown_whenRepositoryThrows() {
        when(userRepository.count()).thenThrow(new RuntimeException("DB error"));

        Health health = databaseHealthIndicator.health();

        assertEquals(Status.DOWN, health.getStatus());
        assertEquals("DB error", health.getDetails().get("error"));
    }
}
