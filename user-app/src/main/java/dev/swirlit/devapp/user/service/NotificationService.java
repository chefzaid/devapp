package dev.swirlit.devapp.user.service;

import org.springframework.stereotype.Service;

import dev.swirlit.devapp.common.domain.Order;
import dev.swirlit.devapp.common.domain.User;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
public class NotificationService {
    public void notifyUser(User user, Order order) {
        log.info("Notify user {} about order {}", user.getName(), order.getId());
    }
}
