package io.simpleit.devapp.user.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app")
public class AppProperties {
    
    private Security security = new Security();
    
    public Security getSecurity() {
        return security;
    }
    
    public void setSecurity(Security security) {
        this.security = security;
    }
    
    public static class Security {
        private String user = "admin";
        private String password = "password";
        
        public String getUser() {
            return user;
        }
        
        public void setUser(String user) {
            this.user = user;
        }
        
        public String getPassword() {
            return password;
        }
        
        public void setPassword(String password) {
            this.password = password;
        }
    }
}
