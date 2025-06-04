package io.simpleit.devapp.order.controller;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;

import io.simpleit.devapp.common.domain.Order;
import io.simpleit.devapp.order.service.OrderService;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

	@Autowired
	private OrderService orderService;

        @GetMapping
        public List<Order> getAllOrders(@AuthenticationPrincipal OidcUser user) {
                return orderService.getAllOrders();
        }

        @GetMapping("/{id}")
        public Optional<Order> getOrder(@AuthenticationPrincipal OidcUser user, @PathVariable Long id) {
                return orderService.getOrderById(id);
        }

        @PostMapping
        public Order createOrder(@AuthenticationPrincipal OidcUser user, @RequestBody Order order) {
                return orderService.createOrder(order);
        }

}
