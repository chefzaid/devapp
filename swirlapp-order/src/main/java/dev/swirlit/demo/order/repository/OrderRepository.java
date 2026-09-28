package dev.swirlit.demo.order.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import dev.swirlit.demo.order.domain.Order;

public interface OrderRepository extends JpaRepository<Order, Long> {
}
