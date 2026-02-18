package io.simpleit.devapp.common.domain;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnore;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Column;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.ToString;

@Entity
@Data
@ToString(exclude = "orders")
@Table(name = "users")
public class User {
	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;

	@NotBlank
	private String name;

	@NotBlank
	@Column(unique = true)
	private String username;

	@NotBlank
	@JsonIgnore
	private String password;
	
	@OneToMany(mappedBy = "user")
        @JsonIgnore
	List<Order> orders;
}
