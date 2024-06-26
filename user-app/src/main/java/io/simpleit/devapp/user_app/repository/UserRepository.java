package io.simpleit.devapp.user_app.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import io.simpleit.devapp.common.domain.User;

public interface UserRepository extends JpaRepository<User, Long> {
}
