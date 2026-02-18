-- Centralized Database Schema for DevApp
-- This schema is shared between user-app and order-app

-- User table
CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL
);

-- Order table
CREATE TABLE IF NOT EXISTS order_table (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT NOT NULL,
    status VARCHAR(50),
    user_id BIGINT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
