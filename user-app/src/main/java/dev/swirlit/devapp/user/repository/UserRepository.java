package dev.swirlit.devapp.user.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import dev.swirlit.devapp.common.domain.User;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
}
