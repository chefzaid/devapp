package io.simpleit.devapp.user.controller;

import java.util.List;

import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
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

        @PostMapping
        public User createUser(@Valid @RequestBody User u) {
                return userService.createUser(u);
        }
}
