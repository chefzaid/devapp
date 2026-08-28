package dev.swirlit.devapp.user.dto;

import java.time.Instant;

import dev.swirlit.devapp.user.domain.User;

public record UserResponse(
        Long id,
        String name,
        String username,
        String email,
        Instant createdDate,
        Instant lastModifiedDate) {

    public static UserResponse from(User user) {
        return new UserResponse(
                user.getId(), user.getName(), user.getUsername(), user.getEmail(),
                user.getCreatedDate(), user.getLastModifiedDate());
    }
}
