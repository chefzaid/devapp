package io.simpleit.devapp.order.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Data
@Component
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private Security security = new Security();

    @Data
    public static class Security {
        private String user = "admin";
        private String password = "password";
    }
}
