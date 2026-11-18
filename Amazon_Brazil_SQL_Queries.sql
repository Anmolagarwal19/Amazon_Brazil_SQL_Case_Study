-- Q1. Find the total number of orders fulfilled by each seller state. 

-- Amazon Brazil's logistics team is planning its next round of regional fulfillment center investments. Before committing budget, 
-- they need to know which states are generating the most order volume on the seller side — so infrastructure goes where the actual demand is. 

SELECT 
    s.seller_state, COUNT(distinct o1.order_id) AS total_orders
FROM
    sellers s
        JOIN
    order_items o1 USING (seller_id)
GROUP BY 1
ORDER BY total_orders DESC;

 -- Result: SP leads with 70,188 orders, far ahead of MG (7,930) and PR (7,673). 

-- Q2. For each product category, calculate the cumulative revenue generated as orders come in over time. 

-- The growth team wants to see how revenue builds up within each category across the order timeline. 
-- This running total helps them spot which categories hit their revenue targets early in the month versus
 -- which ones pick up only toward the end — useful for planning flash sales and push notifications. 
 
SELECT 
    p.product_category_name,
    o.order_purchase_timestamp,
    SUM(pay.payment_value) AS revenue,
     SUM(SUM(pay.payment_value)) OVER (
        PARTITION BY p.product_category_name
        ORDER BY o.order_purchase_timestamp
    ) AS cumulative_revenue

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
JOIN order_payments pay
    ON o.order_id = pay.order_id
    where product_category_name is not null
GROUP BY 
    p.product_category_name,
    o.order_purchase_timestamp
ORDER BY 
    p.product_category_name,
    o.order_purchase_timestamp;
    
    
    with category_revenue as 
    ( 
    
    select p.product_category_name, 
    date(o.order_purchase_timestamp) as purchase_date,
    sum(oi.price) as total_revenue
    
from products p
join order_items oi
on p.product_id = oi.product_id
join orders o
on oi.order_id = o.order_id
group by 

   1,2)
   
   select cr.product_category_name, purchase_date, total_revenue, sum(cr.total_revenue) over (partition by cr.product_category_name order by
purchase_date asc) as cumulative_revenue
from category_revenue cr;
    
   -- Q3. Which payment method do customers use the most, and what is the average order value for each payment type? 

-- The finance and partnerships team is renegotiating contracts with payment providers.
-- Before those talks, they need to know which payment method 
-- — credit card, boleto, voucher, or debit card — dominates the platform, and whether high-value orders cluster around a specific payment type.

SELECT 
    pay.payment_type,
    COUNT(*) AS usage_count,
    ROUND(AVG(pay.payment_value), 2) 
    AS avg_order_value
FROM
    order_payments pay
GROUP BY pay.payment_type
ORDER BY usage_count DESC; 
--  Result: credit_card dominates (76,795 uses, AOV R$163.32), then boleto (19,784, R$145.03).

-- Q4. Find the customer who has spent the most money across all their orders. 

-- The CRM team is launching Amazon Brazil's first premium loyalty tier. 
-- The first step is identifying the single highest-spending customer on the platform —
-- both to personally onboard them into the program and to understand what a top-tier customer profile looks like. 

select c.customer_id, sum(pay.payment_value)as total_payments from
customers c join orders o using(customer_id)
join order_payments pay using(order_id)
group by 1
order by sum(pay.payment_value) desc
limit 1;

-- Q5. Find the average review score for each product category. 

-- The customer experience team tracks satisfaction at the category level.
-- A low average review score in a category often signals a fulfillment issue, a product quality problem, 
 -- or a mismatch between listing description and actual product. This query helps them prioritize which categories need intervention first.
 
 select p.product_category_name , avg(rev.review_score) as avg_rev from
  products p join order_items
 using(product_id)
 join order_reviews rev
 using(order_id)
 group by 1
 order by avg_rev desc;

-- Result: CDs/DVDs (4.64) highest; security_and_services (2.50) lowest. 
 
-- Q6. Find the total number of orders placed by each customer, broken down by the state they live in. 

-- The regional marketing team is planning state-level campaigns in Brazil. 
-- They want to know how order frequency varies by customer location —
-- so they can target low-frequency states with acquisition offers and reward high-frequency states with loyalty perks. 

select c.customer_id, c.customer_state, count(o.order_id)
from customers c join orders o
using (customer_id)
group by 1,2
order by c.customer_state;
-- Note: each customer_id maps to one order (customer_unique_id tracks repeat -- buyers), so most rows = 1. SP has the most customers overall. 

-- Q7. Identify sellers who registered on the platform but have never fulfilled a single order. 

-- The seller growth team runs quarterly re-engagement campaigns targeting dormant sellers.
 -- To build that list, they need to find every seller account that exists in the system
 -- but has zero fulfilled orders — these are the accounts that need a nudge or need to be reviewed for removal.
 
 SELECT 
    s.seller_id, s.seller_state
FROM
    sellers s
        LEFT JOIN
    order_items oi ON s.seller_id = oi.seller_id
WHERE
    oi.order_id IS NULL;
    -- Result: 0 rows — every seller in this dataset has at least one order. 
    
-- Q8. Find the top 5 product categories by total revenue. 

-- Before every major sales event — Black Friday Brazil, Dia das Mães, Cyber Monday —
 -- the merchandising team decides which categories get homepage real estate and promotional budget.
 -- Total revenue by category is the primary input for that decision.
 
SELECT 
    p.product_category_name,
    ROUND(SUM(pay.payment_value), 2) AS total_revenue
FROM
    products p
        JOIN
    order_items oi ON p.product_id = oi.product_id
        JOIN
    order_payments pay ON oi.order_id = pay.order_id
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 5;
-- Result: bed_bath_table (R$1.71M), health_beauty (R$1.66M), 
--         computers_accessories (R$1.59M), furniture_decor, watches_gifts. 

-- Q9. Find the median delivery time (in days) between order placement and actual delivery. 

-- The logistics director wants to know the true middle ground of how long customers wait for their orders.
 -- The median is preferred over the average here because a handful of extremely delayed orders 
 -- (due to remote delivery locations in Brazil's interior) would skew the average and make performance look worse than it is for most customers. 
WITH delivery AS (
    SELECT 
        DATEDIFF(
            order_delivered_customer_date,
            order_purchase_timestamp
        ) AS delivery_days
    FROM orders WHERE order_delivered_customer_date IS NOT NULL
),
ranked AS (
    SELECT 
        delivery_days,
        ROW_NUMBER() OVER (ORDER BY delivery_days) AS rn,
        COUNT(*) OVER () AS total_rows
    FROM delivery)
    SELECT AVG(delivery_days) AS median_delivery_days
FROM ranked
WHERE rn IN (
    FLOOR((total_rows + 1) / 2),
    CEIL((total_rows + 1) / 2)
);         
-- Result: 10 days.

-- Q10. Find all products that have never been ordered. 

-- The catalogue operations team does a quarterly clean-up of dead listings. 
-- Products that have never received a single order waste search index space, confuse customers,
--  and inflate category browse pages. This query gives them the exact list to review, reprice, or remove. 
SELECT 
    p.product_id, p.product_category_name
FROM
    products p
        LEFT JOIN
    order_items oi ON p.product_id = oi.product_id
WHERE
    oi.order_id IS NULL;
    -- Result: 0 rows — every product in this dataset was ordered at least once. 
    
-- Q11. Find sellers who have fulfilled more orders than the average seller on the platform. 

-- The seller success team is building an invite list for Amazon Brazil's "Top Seller" badge program.
-- Only sellers who perform above the platform average qualify. This query identifies exactly who clears that bar —
-- and gives the team a baseline for what above-average performance actually means numerically. 

WITH seller_orders AS ( SELECT seller_id, COUNT(DISTINCT order_id) AS order_count
 FROM  order_items GROUP  BY seller_id ) 
SELECT seller_id, order_count FROM  seller_orders 
WHERE  order_count > (SELECT AVG(order_count) FROM seller_orders) 
ORDER  BY order_count DESC;
with seller_orders as ( 
select s.seller_id,
count(distinct oi.order_id) as total_no_of_orders
from sellers s
left join order_items oi
on s.seller_id = oi.seller_id group by s.seller_id),

average_orders as (
select so.seller_id,
so.total_no_of_orders, avg(so.total_no_of_orders) over() as average_no_of_orders
from seller_orders so)

select ao.seller_id, ao.total_no_of_orders, ao.average_no_of_orders
from average_orders 
where ao.total_no_of_orders > ao.average_no_of_orders;


 -- Result: 590 sellers clear the platform average of ~32.31 orders. 
 
 -- Q12. Find which Brazilian states have the highest average customer review score for orders delivered there. 

-- The last-mile delivery experience varies significantly across Brazil —
--  deliveries to São Paulo and Rio are generally faster and smoother than to states in the North and Northeast.
--  This query helps the CX team correlate delivery destination with satisfaction,
--  so they can push logistics partners to improve in underperforming states. 
   
 SELECT 
    c.customer_state,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM
    customers c
        JOIN
    orders o ON c.customer_id = o.customer_id
        JOIN
    order_reviews r ON o.order_id = r.order_id
GROUP BY c.customer_state
ORDER BY avg_review_score DESC; -- Result: AP (4.19), PR & AM (4.18) top; scores tightly banded 3.8-4.2.

with state_wise_reviews as
(
 select c.customer_state,
 round(avg(rev.review_score),2) as avg_customer_rev_score
 from customers c join orders o 
 using(customer_id)
 join order_reviews rev
 using(order_id)
 group by 1)
 
 select swr.customer_state, swr.avg_customer_rev_score,
 dense_rank() over(order by avg_customer_rev_score desc) as state_rank 
 
from state_wise_reviews swr;
-- Q13. Identify customers who have placed orders but never left a review. 

-- The post-purchase engagement team wants to grow the volume of reviews on the platform —
--  more reviews mean better product discoverability and buyer trust. 
-- The first step is identifying customers who buy regularly but never review,
-- so the team can target them with review reminder emails and in-app nudges. 

SELECT DISTINCT
    c.customer_id
FROM
    customers c
        JOIN
    orders o ON c.customer_id = o.customer_id
        LEFT JOIN
    order_reviews r ON o.order_id = r.order_id
WHERE
    r.review_id IS NULL;
 -- Result: 768 customers ordered but never reviewed. 

SELECT DISTINCT o.customer_id
FROM orders o
LEFT JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE r.review_id IS NULL;-- order_delivered_customer_date

-- Q14. Find the month with the highest number of orders placed across the entire platform. 

-- The demand forecasting team needs to know Amazon Brazil's peak order month historically. 
-- This drives decisions about how much warehouse capacity to reserve, how many temporary delivery staff to hire,
--  and when to start marketing campaigns for the next peak season. 

SELECT 
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(order_id) AS total_orders
FROM
    orders
GROUP BY order_month
ORDER BY total_orders DESC
LIMIT 1;
 -- Result: 2017-11 (November 2017) — 7,544 orders, driven by Black Friday. ; 
 
 SELECT 
    YEAR(order_purchase_timestamp) AS year,
    MONTH(order_purchase_timestamp) AS month,
    COUNT(*) AS total_orders
FROM orders
GROUP BY YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp)
ORDER BY total_orders DESC;









 