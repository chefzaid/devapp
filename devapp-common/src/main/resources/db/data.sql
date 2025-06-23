-- Centralized Test Data for DevApp
-- This data is shared between user-app and order-app

-- Insert sample users
INSERT INTO user (name) VALUES ('John Doe');
INSERT INTO user (name) VALUES ('Jane Smith');
INSERT INTO user (name) VALUES ('Bob Johnson');
INSERT INTO user (name) VALUES ('Alice Brown');
INSERT INTO user (name) VALUES ('Charlie Wilson');

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
