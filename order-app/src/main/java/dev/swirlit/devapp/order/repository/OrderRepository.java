package dev.swirlit.devapp.order.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import dev.swirlit.devapp.order.domain.Order;

public interface OrderRepository extends JpaRepository<Order, Long> {
}
