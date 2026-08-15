package dev.swirlit.devapp.user.service;

import java.util.List;

import dev.swirlit.devapp.user.domain.User;
import dev.swirlit.devapp.user.dto.CreateUserRequest;
import dev.swirlit.devapp.user.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;

import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public List<User> getAllUsers() {
        return userRepository.findAll(Sort.by(Sort.Direction.ASC, "name"));
    }

    @Transactional(readOnly = true)
    @Cacheable(cacheNames = "users", key = "#userId")
    public User getUser(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new EntityNotFoundException("User %d was not found".formatted(userId)));
    }

    @Transactional
    @CacheEvict(cacheNames = "users", allEntries = true)
    public User createUser(CreateUserRequest request) {
        User user = new User(request.name().trim(), request.username().trim(), request.email().trim().toLowerCase());
        return userRepository.save(user);
    }
}
