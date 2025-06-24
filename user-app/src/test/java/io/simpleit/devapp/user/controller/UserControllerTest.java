package io.simpleit.devapp.user.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.simpleit.devapp.common.domain.User;
import io.simpleit.devapp.user.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(controllers = UserController.class,
    excludeAutoConfiguration = {
        org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration.class,
        org.springframework.boot.autoconfigure.kafka.KafkaAutoConfiguration.class,
        org.springframework.boot.autoconfigure.data.redis.RedisAutoConfiguration.class
    })
@TestPropertySource(properties = {
    "spring.kafka.bootstrap-servers=localhost:9092",
    "spring.data.redis.host=localhost",
    "spring.data.redis.port=6379"
})
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void getAllUsers_ShouldReturnUserList() throws Exception {
        // Given
        User user1 = new User();
        user1.setId(1L);
        user1.setName("John Doe");
        
        User user2 = new User();
        user2.setId(2L);
        user2.setName("Jane Smith");
        
        List<User> users = Arrays.asList(user1, user2);
        when(userService.getAllUsers()).thenReturn(users);

        // When & Then
        mockMvc.perform(get("/api/users"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].name").value("John Doe"))
                .andExpect(jsonPath("$[1].id").value(2))
                .andExpect(jsonPath("$[1].name").value("Jane Smith"));
    }

    @Test
    void getUserById_ShouldReturnUser() throws Exception {
        // Given
        User user = new User();
        user.setId(1L);
        user.setName("John Doe");
        when(userService.getUser(1L)).thenReturn(user);

        // When & Then
        mockMvc.perform(get("/api/users/1"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("John Doe"));
    }

    @Test
    void createUser_ShouldReturnCreatedUser() throws Exception {
        // Given
        User inputUser = new User();
        inputUser.setName("New User");

        User savedUser = new User();
        savedUser.setId(1L);
        savedUser.setName("New User");

        when(userService.createUser(any(User.class))).thenReturn(savedUser);

        // When & Then
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(inputUser)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("New User"));
    }

    @Test
    void createUser_WithInvalidData_ShouldReturnBadRequest() throws Exception {
        // Given
        User invalidUser = new User();
        // name is null/empty - should trigger validation error

        // When & Then
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(invalidUser)))
                .andExpect(status().isBadRequest());
    }
}
