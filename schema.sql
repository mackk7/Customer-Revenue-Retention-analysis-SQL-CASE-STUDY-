-- SCHEMA DEFINITION FOR CUSTOMER ORDERS & REVENUE ANALYSIS 
create table customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(50),
    signup_date DATE,
    city VARCHAR(30)
);

create table orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    order_amount NUMERIC(10,2),
    payment_method VARCHAR(20),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

create table order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_category VARCHAR(30),
    quantity INT,
    price NUMERIC(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);