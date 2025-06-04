package io.simpleit.devapp.user.service;

import java.util.List;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;

import io.simpleit.devapp.common.domain.User;
import io.simpleit.devapp.user.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
@RequiredArgsConstructor
public class UserService {

        private final UserRepository userRepository;

        public List<User> getAllUsers() {
                log.info("Fetching users");
                return userRepository.findAll();
        }

        @Cacheable(value = "users", key = "#userId")
        public User getUser(Long userId) {
                return userRepository.findById(userId)
                        .orElseThrow(() -> new EntityNotFoundException("User not found"));
        }

        public User createUser(User user) {
                return userRepository.save(user);
        }
}
