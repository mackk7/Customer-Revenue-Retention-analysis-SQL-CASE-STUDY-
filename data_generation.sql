-- creating data using sql , its Synthetic but Behaviourally realistic Data generation

insert into customers values
(1,'Amit','2023-01-10','Delhi'),
(2,'Riya','2023-01-15','Mumbai'),
(3,'Karan','2023-02-01','Delhi'),
(4,'Sneha','2023-02-10','Bangalore'),
(5,'Arjun','2023-03-05','Mumbai'),
(6,'Neha','2023-03-12','Delhi'),
(7,'Rahul','2023-04-01','Pune'),
(8,'Ananya','2023-04-18','Bangalore');
insert into orders values
(101,1,'2023-01-15',2500,'UPI'),
(102,2,'2023-01-20',1800,'Card'),
(103,1,'2023-02-05',3200,'UPI'),
(104,3,'2023-02-10',1500,'COD'),
(105,4,'2023-02-20',4000,'Card'),
(106,2,'2023-03-01',2200,'UPI'),
(107,5,'2023-03-15',2700,'Card'),
(108,1,'2023-04-02',3500,'UPI'),
(109,6,'2023-04-10',1600,'COD'),
(110,7,'2023-04-20',2900,'Card'),
(111,2,'2023-05-01',3100,'UPI'),
(112,8,'2023-05-10',2600,'Card');
INSERT INTO order_items VALUES
(1,101,'Electronics',1,2500),
(2,102,'Fashion',2,900),
(3,103,'Electronics',1,3200),
(4,104,'Home',1,1500),
(5,105,'Electronics',2,2000),
(6,106,'Beauty',2,1100),
(7,107,'Fashion',3,900),
(8,108,'Electronics',1,3500),
(9,109,'Home',1,1600),
(10,110,'Sports',2,1450),
(11,111,'Electronics',1,3100),
(12,112,'Fashion',2,1300);
TRUNCATE order_items, orders, customers RESTART IDENTITY CASCADE;
INSERT INTO customers (customer_id, customer_name, signup_date, city)
SELECT
    id,
    'Customer_' || id,
    DATE '2023-01-01' + (id * INTERVAL '2 days'),
    (ARRAY['Delhi','Mumbai','Bangalore','Pune','Hyderabad'])[1 + (id % 5)]
FROM generate_series(1,100) AS id;
INSERT INTO orders (order_id, customer_id, order_date, order_amount, payment_method)
SELECT
    id,

    -- CUSTOMER VALUE SKEW (TOP 20 ARE POWER USERS)
    CASE
        WHEN random() < 0.6 THEN 1 + (random() * 19)::INT
        ELSE 21 + (random() * 79)::INT
    END AS customer_id,

    -- DATE DISTRIBUTION (6 MONTHS)
    DATE '2023-01-01' + (random() * 180)::INT AS order_date,

    -- REALISTIC ORDER AMOUNT
    ROUND((700 + random() * 5000)::NUMERIC, 2) AS order_amount,

    -- PAYMENT METHOD BIAS
    CASE
        WHEN random() < 0.45 THEN 'UPI'
        WHEN random() < 0.8 THEN 'Card'
        WHEN random() < 0.95 THEN 'Wallet'
        ELSE 'COD'
    END AS payment_method

FROM generate_series(1,700) AS id;
INSERT INTO order_items (order_item_id, order_id, product_category, quantity, price)
SELECT
    row_number() OVER (),
    o.order_id,

    -- CATEGORY DOMINANCE
    CASE
        WHEN random() < 0.4 THEN 'Electronics'
        WHEN random() < 0.7 THEN 'Fashion'
        WHEN random() < 0.85 THEN 'Home'
        WHEN random() < 0.95 THEN 'Beauty'
        ELSE 'Sports'
    END AS product_category,

    1 + (random() * 2)::INT AS quantity,

    ROUND((300 + random() * 3000)::NUMERIC, 2) AS price

FROM orders o
CROSS JOIN generate_series(1, (1 + random() * 2)::INT);
