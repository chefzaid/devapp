package io.simpleit.devapp.user.controller;

import java.util.List;

import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.simpleit.devapp.common.domain.User;
import io.simpleit.devapp.user.service.UserService;

@RestController
@RequestMapping("/api/users")
public class UserController {

        private final UserService userService;

        public UserController(UserService userService) {
                this.userService = userService;
        }

        @GetMapping
        public List<User> getAllUsers() {
                return userService.getAllUsers();
        }

        @GetMapping("/{id}")
        public User getUserById(@PathVariable Long id) {
                return userService.getUser(id);
        }

        @PostMapping
        public User createUser(@Valid @RequestBody User user) {
                return userService.createUser(user);
        }
}
