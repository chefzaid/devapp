package io.simpleit.devapp.user.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import io.simpleit.devapp.common.domain.User;
import io.simpleit.devapp.user.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
public class UserService {

	@Autowired
	private UserRepository userRepository;

	public List<User> getAllUsers() {
		log.info("Fetching users");
		return userRepository.findAll();
	}

	public User getUser(Long userId) {
		return userRepository.findById(userId).get();
	}

	public User createUser(User user) {
		return userRepository.save(user);
	}
}
