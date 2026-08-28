package dev.swirlit.devapp.user.service;

import java.util.List;
import java.util.Locale;

import dev.swirlit.devapp.common.exception.ResourceConflictException;
import dev.swirlit.devapp.user.domain.User;
import dev.swirlit.devapp.user.dto.CreateUserRequest;
import dev.swirlit.devapp.user.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;

import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.PageRequest;
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
    public List<User> getAllUsers(int limit) {
        return userRepository.findAll(PageRequest.of(0, limit, Sort.by(Sort.Direction.ASC, "name"))).getContent();
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
        String username = request.username().trim().toLowerCase(Locale.ROOT);
        String email = request.email().trim().toLowerCase(Locale.ROOT);
        if (userRepository.existsByUsername(username)) {
            throw new ResourceConflictException("The username is already in use");
        }
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new ResourceConflictException("The email address is already in use");
        }

        User user = new User(request.name().trim(), username, email);
        return userRepository.save(user);
    }
}
