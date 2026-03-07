package dev.swirlit.devapp.order;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import dev.swirlit.devapp.common.exception.GlobalExceptionHandler;

@SpringBootApplication
@EntityScan("dev.swirlit.devapp.common.domain")
@ComponentScan(
    basePackages = {"dev.swirlit.devapp.order", "dev.swirlit.devapp.common"},
    excludeFilters = @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = GlobalExceptionHandler.class)
)
public class OrderAppApplication {

	public static void main(String[] args) {
		SpringApplication.run(OrderAppApplication.class, args);
	}

}
