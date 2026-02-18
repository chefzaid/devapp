-- Centralized Test Data for DevApp
-- This data is shared between user-app and order-app

-- Insert sample users
INSERT INTO users (name, username, password) VALUES ('John Doe', 'john.doe', '$2a$10$slYQmyNdGzTn7ZLBXBChFOC9f6kFjAqPhccnP6DxlWXx2lPk1C3G6');
INSERT INTO users (name, username, password) VALUES ('Jane Smith', 'jane.smith', '$2a$10$slYQmyNdGzTn7ZLBXBChFOC9f6kFjAqPhccnP6DxlWXx2lPk1C3G6');
INSERT INTO users (name, username, password) VALUES ('Bob Johnson', 'bob.johnson', '$2a$10$slYQmyNdGzTn7ZLBXBChFOC9f6kFjAqPhccnP6DxlWXx2lPk1C3G6');
INSERT INTO users (name, username, password) VALUES ('Alice Brown', 'alice.brown', '$2a$10$slYQmyNdGzTn7ZLBXBChFOC9f6kFjAqPhccnP6DxlWXx2lPk1C3G6');
INSERT INTO users (name, username, password) VALUES ('Charlie Wilson', 'charlie.wilson', '$2a$10$slYQmyNdGzTn7ZLBXBChFOC9f6kFjAqPhccnP6DxlWXx2lPk1C3G6');

-- Insert sample orders
INSERT INTO order_table (product_id, status, user_id) VALUES (1001, 'PENDING', 1);
INSERT INTO order_table (product_id, status, user_id) VALUES (1002, 'COMPLETED', 1);
INSERT INTO order_table (product_id, status, user_id) VALUES (2001, 'PENDING', 2);
INSERT INTO order_table (product_id, status, user_id) VALUES (3001, 'SHIPPED', 3);
INSERT INTO order_table (product_id, status, user_id) VALUES (4001, 'CANCELLED', 4);
INSERT INTO order_table (product_id, status, user_id) VALUES (5001, 'PROCESSING', 5);
INSERT INTO order_table (product_id, status, user_id) VALUES (6001, 'DELIVERED', 1);
INSERT INTO order_table (product_id, status, user_id) VALUES (7001, 'PENDING', 2);
INSERT INTO order_table (product_id, status, user_id) VALUES (8001, 'SHIPPED', 3);
INSERT INTO order_table (product_id, status, user_id) VALUES (9001, 'COMPLETED', 4);
