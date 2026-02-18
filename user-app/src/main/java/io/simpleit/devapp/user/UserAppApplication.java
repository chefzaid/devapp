package io.simpleit.devapp.user;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import io.simpleit.devapp.common.exception.GlobalExceptionHandler;

@SpringBootApplication
@EntityScan("io.simpleit.devapp.common.domain")
@ComponentScan(
    basePackages = {"io.simpleit.devapp.user", "io.simpleit.devapp.common"},
    excludeFilters = @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = GlobalExceptionHandler.class)
)
public class UserAppApplication {

	public static void main(String[] args) {
		SpringApplication.run(UserAppApplication.class, args);
	}

}
