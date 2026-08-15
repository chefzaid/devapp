package dev.swirlit.devapp.user.service;

import java.util.List;
import java.util.Optional;

import dev.swirlit.devapp.user.domain.User;
import dev.swirlit.devapp.user.dto.CreateUserRequest;
import dev.swirlit.devapp.user.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Sort;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;
    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = new UserService(userRepository);
    }

    @Test
    void getAllUsersSortsByName() {
        User user = new User("Ada", "ada", "ada@example.test");
        when(userRepository.findAll(any(Sort.class))).thenReturn(List.of(user));

        assertEquals(List.of(user), userService.getAllUsers());
    }

    @Test
    void getUserReturnsProfile() {
        User user = new User("Ada", "ada", "ada@example.test");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        assertEquals(user, userService.getUser(1L));
    }

    @Test
    void createUserNormalizesInput() {
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        userService.createUser(new CreateUserRequest(" Ada ", "ada", "ADA@EXAMPLE.TEST "));

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        org.mockito.Mockito.verify(userRepository).save(captor.capture());
        assertEquals("Ada", captor.getValue().getName());
        assertEquals("ada@example.test", captor.getValue().getEmail());
    }

    @Test
    void getUserRejectsUnknownId() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(EntityNotFoundException.class, () -> userService.getUser(99L));
    }
}
