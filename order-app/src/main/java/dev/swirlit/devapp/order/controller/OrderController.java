package dev.swirlit.devapp.order.controller;

import java.net.URI;
import java.util.List;

import dev.swirlit.devapp.order.dto.CreateOrderRequest;
import dev.swirlit.devapp.order.dto.OrderResponse;
import dev.swirlit.devapp.order.service.OrderService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping
    public List<OrderResponse> getAllOrders(
            @RequestParam(defaultValue = "100") @Min(1) @Max(100) int limit) {
        return orderService.getAllOrders(limit).stream().map(OrderResponse::from).toList();
    }

    @GetMapping("/{id}")
    public OrderResponse getOrder(@PathVariable @Positive Long id) {
        return OrderResponse.from(orderService.getOrderById(id));
    }

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        var created = orderService.createOrder(request);
        return ResponseEntity.created(URI.create("/api/orders/" + created.getId()))
                .body(OrderResponse.from(created));
    }
}
