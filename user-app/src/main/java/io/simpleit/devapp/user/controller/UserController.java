package io.simpleit.devapp.user.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
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

	@Autowired
	private UserService userService;

        @GetMapping
        public List<User> getAllUsers() {
                return userService.getAllUsers();
        }

        @PostMapping
        public User createUser(@RequestBody User u) {
                return userService.createUser(u);
        }
}
