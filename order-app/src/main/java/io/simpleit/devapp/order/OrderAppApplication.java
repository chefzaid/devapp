package io.simpleit.devapp.order;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import io.simpleit.devapp.common.exception.GlobalExceptionHandler;

@SpringBootApplication
@EntityScan("io.simpleit.devapp.common.domain")
@ComponentScan(
    basePackages = {"io.simpleit.devapp.order", "io.simpleit.devapp.common"},
    excludeFilters = @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = GlobalExceptionHandler.class)
)
public class OrderAppApplication {

	public static void main(String[] args) {
		SpringApplication.run(OrderAppApplication.class, args);
	}

}
