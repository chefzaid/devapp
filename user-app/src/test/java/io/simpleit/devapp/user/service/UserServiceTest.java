package io.simpleit.devapp.user.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.List;
import java.util.Optional;

import io.simpleit.devapp.common.domain.User;
import io.simpleit.devapp.user.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;
    @InjectMocks
    private UserService userService;

    private User user;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setName("test");
    }

    @Test
    void getAllUsers_returnsUsers() {
        List<User> users = List.of(user);
        when(userRepository.findAll()).thenReturn(users);

        List<User> result = userService.getAllUsers();

        assertEquals(users, result);
    }

    @Test
    void getUser_returnsUser() {
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        User result = userService.getUser(1L);

        assertEquals(user, result);
    }

    @Test
    void createUser_savesUser() {
        when(userRepository.save(user)).thenReturn(user);

        User result = userService.createUser(user);

        assertEquals(user, result);
    }

    @Test
    void getUser_whenNotFound_throwsEntityNotFoundException() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(EntityNotFoundException.class, () -> userService.getUser(99L));
    }
}
