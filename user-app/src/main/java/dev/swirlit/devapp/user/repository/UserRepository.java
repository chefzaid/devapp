package dev.swirlit.devapp.user.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import dev.swirlit.devapp.user.domain.User;

public interface UserRepository extends JpaRepository<User, Long> {

    boolean existsByUsername(String username);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByUsernameAndIdNot(String username, Long id);

    boolean existsByEmailIgnoreCaseAndIdNot(String email, Long id);
}
