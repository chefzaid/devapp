package io.simpleit.devapp.order_app.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import io.simpleit.devapp.common.domain.Order;

public interface OrderRepository extends JpaRepository<Order, Long> {
}