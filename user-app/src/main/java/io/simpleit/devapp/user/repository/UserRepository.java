package io.simpleit.devapp.user.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import io.simpleit.devapp.common.domain.User;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
}
