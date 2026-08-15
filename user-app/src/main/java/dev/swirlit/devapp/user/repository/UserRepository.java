package dev.swirlit.devapp.user.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import dev.swirlit.devapp.user.domain.User;

public interface UserRepository extends JpaRepository<User, Long> {
}
