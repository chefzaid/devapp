package dev.swirlit.devapp.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UpdateUserRequest(
        @NotBlank @Size(max = 120) String name,
        @NotBlank @Size(max = 80)
        @Pattern(regexp = "[a-z0-9._-]+", message = "must contain only lowercase letters, numbers, dots, dashes, or underscores")
        String username,
        @NotBlank @Email @Size(max = 180) String email) {
}
