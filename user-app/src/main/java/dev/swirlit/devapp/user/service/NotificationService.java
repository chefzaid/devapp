package dev.swirlit.devapp.user.service;

import dev.swirlit.devapp.common.event.OrderEvent;
import dev.swirlit.devapp.user.domain.User;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    public void notifyUser(User user, OrderEvent order) {
        log.info("Demo notification user={} order={} product={}", user.getUsername(), order.orderId(), order.productId());
    }
}
