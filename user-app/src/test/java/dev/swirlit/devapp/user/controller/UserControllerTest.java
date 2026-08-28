package dev.swirlit.devapp.user.controller;

import java.util.List;

import dev.swirlit.devapp.common.exception.GlobalExceptionHandler;
import dev.swirlit.devapp.user.domain.User;
import dev.swirlit.devapp.user.dto.CreateUserRequest;
import dev.swirlit.devapp.user.service.UserService;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.cache.CacheManager;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(UserController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler.class)
@TestPropertySource(properties = "app.security.enabled=false")
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @MockitoBean
    private CacheManager cacheManager;

    @Test
    void getAllUsersReturnsProfiles() throws Exception {
        User ada = user(1L, "Ada Lovelace", "ada", "ada@example.test");
        User grace = user(2L, "Grace Hopper", "grace", "grace@example.test");
        when(userService.getAllUsers(100)).thenReturn(List.of(ada, grace));

        mockMvc.perform(get("/api/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].username").value("ada"))
                .andExpect(jsonPath("$[1].email").value("grace@example.test"))
                .andExpect(jsonPath("$[0].createdBy").doesNotExist())
                .andExpect(jsonPath("$[0].version").doesNotExist());
    }

    @Test
    void getUserReturnsProfile() throws Exception {
        when(userService.getUser(1L)).thenReturn(user(1L, "Ada Lovelace", "ada", "ada@example.test"));

        mockMvc.perform(get("/api/users/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("Ada Lovelace"));
    }

    @Test
    void createUserValidatesAndReturnsLocation() throws Exception {
        User created = user(4L, "Linus Torvalds", "linus", "linus@example.test");
        when(userService.createUser(any(CreateUserRequest.class))).thenReturn(created);

        mockMvc.perform(post("/api/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Linus Torvalds","username":"linus","email":"linus@example.test"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/api/users/4"))
                .andExpect(jsonPath("$.username").value("linus"));
    }

    @Test
    void createUserRejectsInvalidPayload() throws Exception {
        mockMvc.perform(post("/api/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"username\":\"Not Valid\",\"email\":\"bad\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.title").value("Validation failed"));
    }

    @Test
    void rejectsInvalidListLimit() throws Exception {
        mockMvc.perform(get("/api/users").param("limit", "101"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.violations.limit").exists());
    }

    @Test
    void rejectsNonPositiveId() throws Exception {
        mockMvc.perform(get("/api/users/0"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.title").value("Validation failed"));
    }

    @Test
    void rejectsMalformedJson() throws Exception {
        mockMvc.perform(post("/api/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{not-json}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.title").value("Malformed request"));
    }

    private static User user(Long id, String name, String username, String email) {
        User user = new User(name, username, email);
        user.setId(id);
        return user;
    }
}
