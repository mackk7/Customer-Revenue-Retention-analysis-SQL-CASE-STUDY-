/*
Customer Revenue & Retention Quality Analysis
SQL Business Case Study (PostgreSQL)

Business Goal:
The business is experiencing stagnant revenue growth despite increasing order volume.
This analysis evaluates whether future growth should come from:
1) Increasing Average Order Value (AOV)
2) Improving customer retention quality
3) Scaling customer acquisition
*/

--------------------------------------------------
-- BASIC ANALYSIS
--------------------------------------------------

-- 1. TOTAL REVENUE GENERATED
select
    sum(order_amount) as total_revenue
from orders;

-- insight:
-- Establishes the overall revenue baseline used to judge whether
-- growth should be driven by AOV, retention, or acquisition.


-- 2. TOTAL NUMBER OF ORDERS
select
    count(*) as total_orders
from orders;

-- insight:
-- Shows transaction volume. When compared with revenue,
-- it helps identify whether higher activity is translating into growth.


-- 3. AVERAGE ORDER VALUE (AOV)
select
    round(avg(order_amount), 2) as avg_order_value
from orders;

-- insight:
-- Measures spend per transaction. Flat AOV alongside rising orders
-- indicates revenue growth must come from retention, not pricing.


-- 4. MONTHLY REVENUE TREND
select
    date_trunc('month', order_date) as month,
    sum(order_amount) as monthly_revenue
from orders
group by month
order by month;

-- insight:
-- Reveals long-term revenue direction and identifies periods
-- of stagnation despite growing activity.

--------------------------------------------------
-- INTERMEDIATE ANALYSIS
--------------------------------------------------

-- 5. MONTH-OVER-MONTH REVENUE GROWTH
with monthly_revenue as (
    select
        date_trunc('month', order_date) as month,
        sum(order_amount) as revenue
    from orders
    group by month
)
select
    month,
    revenue,
    lag(revenue) over (order by month) as previous_month_revenue,
    round(
        (revenue - lag(revenue) over (order by month))
        / lag(revenue) over (order by month) * 100,
        2
    ) as mom_growth_percent
from monthly_revenue
order by month;

-- insight:
-- Highlights growth consistency. Volatile or flat MoM growth
-- confirms structural revenue issues rather than seasonal effects.


-- 6. TOP 10 CUSTOMERS BY TOTAL SPEND
select
    c.customer_id,
    c.customer_name,
    sum(o.order_amount) as total_spent
from customers c
join orders o
    on c.customer_id = o.customer_id
group by c.customer_id, c.customer_name
order by total_spent desc
limit 10;

-- insight:
-- Shows revenue concentration and dependency on high-value customers,
-- increasing the importance of retaining this segment.


-- 7. REPEAT CUSTOMERS (ORDER COUNT > 1)
select
    customer_id,
    count(*) as order_count
from orders
group by customer_id
having count(*) > 1
order by order_count desc;

-- insight:
-- Identifies customers contributing to recurring revenue
-- and forms the basis for retention analysis.


-- 8. REVENUE FROM REPEAT VS ONE-TIME CUSTOMERS
with customer_orders as (
    select
        customer_id,
        count(*) as order_count,
        sum(order_amount) as revenue
    from orders
    group by customer_id
)
select
    case
        when order_count > 1 then 'repeat_customer'
        else 'one_time_customer'
    end as customer_type,
    sum(revenue) as total_revenue
from customer_orders
group by customer_type;

-- insight:
-- Confirms that repeat customers generate a disproportionate share
-- of revenue, making retention more impactful than acquisition.


-- 9. AVERAGE DAYS BETWEEN ORDERS PER CUSTOMER
with ordered_orders as (
    select
        customer_id,
        order_date,
        lag(order_date) over (
            partition by customer_id
            order by order_date
        ) as previous_order_date
    from orders
)
select
    customer_id,
    round(avg(order_date - previous_order_date), 2) as avg_days_between_orders
from ordered_orders
where previous_order_date is not null
group by customer_id
order by avg_days_between_orders;

-- insight:
-- Measures purchase frequency. Shorter gaps indicate stronger engagement
-- and higher lifetime value potential.

--------------------------------------------------
-- ADVANCED / RETENTION QUALITY ANALYSIS
--------------------------------------------------

-- 10. EARLY CHURN RATE (CUSTOMERS WITH ONLY ONE ORDER)
with customer_orders as (
    select
        customer_id,
        count(*) as total_orders
    from orders
    group by customer_id
)
select
    count(*) as churned_after_first_purchase,
    round(
        count(*) * 100.0 / sum(count(*)) over (),
        2
    ) as churn_rate_percent
from customer_orders
where total_orders = 1;

-- insight:
-- Quantifies acquisition inefficiency. High early churn suggests
-- first-purchase experience issues rather than pricing problems.


-- 11. MONTHLY CUSTOMER RETENTION RATE
with monthly_customers as (
    select distinct
        customer_id,
        date_trunc('month', order_date) as month
    from orders
),
retained as (
    select
        m1.month,
        count(m1.customer_id) as retained_customers
    from monthly_customers m1
    join monthly_customers m2
        on m1.customer_id = m2.customer_id
       and m1.month = m2.month + interval '1 month'
    group by m1.month
),
total_customers as (
    select
        date_trunc('month', order_date) as month,
        count(distinct customer_id) as total_customers
    from orders
    group by month
)
select
    t.month,
    round(
        coalesce(r.retained_customers, 0)::numeric
        / t.total_customers * 100,
        2
    ) as retention_rate_percent
from total_customers t
left join retained r
    on t.month = r.month
order by t.month;

-- insight:
-- Explains stagnant revenue by showing how many customers
-- continue purchasing month after month.


-- 12. RETENTION BY FIRST-MONTH SPEND (QUALITY SEGMENTATION)
with first_order_month as (
    select
        customer_id,
        date_trunc('month', min(order_date)) as first_month
    from orders
    group by customer_id
),
first_month_revenue as (
    select
        o.customer_id,
        sum(o.order_amount) as first_month_spend
    from orders o
    join first_order_month f
        on o.customer_id = f.customer_id
       and date_trunc('month', o.order_date) = f.first_month
    group by o.customer_id
),
spend_bucket as (
    select
        customer_id,
        case
            when first_month_spend < 1000 then 'low_spend'
            when first_month_spend between 1000 and 3000 then 'mid_spend'
            else 'high_spend'
        end as spend_segment
    from first_month_revenue
),
retained as (
    select distinct
        s.customer_id,
        s.spend_segment
    from spend_bucket s
    join orders o
        on s.customer_id = o.customer_id
       and o.order_date > (
            select min(order_date)
            from orders
            where customer_id = s.customer_id
       )
)
select
    spend_segment,
    count(distinct customer_id) as retained_customers
from retained
group by spend_segment
order by retained_customers desc;

-- insight:
-- Shows that higher first-month spend strongly predicts retention,
-- making early value capture critical for long-term growth.


-- 13. CUSTOMER LIFETIME VALUE (CLV)
select
    customer_id,
    count(*) as total_orders,
    round(avg(order_amount), 2) as avg_order_value,
    sum(order_amount) as lifetime_value
from orders
group by customer_id
order by lifetime_value desc;

-- insight:
-- Identifies customers with the greatest long-term revenue impact,
-- supporting retention and personalization strategies.


-- 14. RETENTION QUALITY VS REVENUE
with customer_value as (
    select
        customer_id,
        count(*) as total_orders,
        sum(order_amount) as lifetime_revenue
    from orders
    group by customer_id
)
select
    case
        when total_orders > 1 then 'retained_customers'
        else 'one_time_customers'
    end as customer_type,
    count(*) as customer_count,
    round(avg(lifetime_revenue), 2) as avg_lifetime_revenue
from customer_value
group by customer_type;

-- insight:
-- Confirms that retained customers generate significantly
-- higher lifetime revenue than one-time buyers.


-- 15. CATEGORY-WISE REVENUE CONTRIBUTION
select
    product_category,
    sum(quantity * price) as revenue
from order_items
group by product_category
order by revenue desc;

-- insight:
-- Identifies product categories that contribute most to revenue,
-- guiding inventory and marketing focus.


-- 16. REVENUE CONTRIBUTION BY CITY
select
    c.city,
    sum(o.order_amount) as revenue,
    round(
        sum(o.order_amount) * 100.0
        / sum(sum(o.order_amount)) over (),
        2
    ) as revenue_percent
from customers c
join orders o
    on c.customer_id = o.customer_id
group by c.city
order by revenue desc;

-- insight:
-- Highlights geographic revenue concentration and supports
-- targeted regional growth strategies.


-- 17. FUNNEL: CUSTOMERS BY ORDER COUNT STAGE
select
    count(*) filter (where order_count = 1) as one_order_customers,
    count(*) filter (where order_count = 2) as two_order_customers,
    count(*) filter (where order_count >= 3) as three_plus_order_customers
from (
    select
        customer_id,
        count(*) as order_count
    from orders
    group by customer_id
) t;

-- insight:
-- Quantifies customer drop-off between first and repeat purchases,
-- highlighting the biggest retention loss point.


-- 18. COHORT-BASED RETENTION (MONTHLY)
with cohorts as (
    select
        customer_id,
        date_trunc('month', min(order_date)) as cohort_month
    from orders
    group by customer_id
),
activity as (
    select
        o.customer_id,
        c.cohort_month,
        date_trunc('month', o.order_date) as activity_month
    from orders o
    join cohorts c
        on o.customer_id = c.customer_id
)
select
    cohort_month,
    activity_month,
    count(distinct customer_id) as active_customers
from activity
group by cohort_month, activity_month
order by cohort_month, activity_month;

-- insight:
-- Tracks long-term engagement patterns across customer cohorts,
-- revealing retention improvements or degradation over time.


-- 19. CUSTOMERS WITH INCREASING SPEND TREND
with customer_monthly as (
    select
        customer_id,
        date_trunc('month', order_date) as month,
        sum(order_amount) as revenue
    from orders
    group by customer_id, month
),
revenue_trend as (
    select
        customer_id,
        month,
        revenue,
        revenue - lag(revenue) over (
            partition by customer_id
            order by month
        ) as revenue_change
    from customer_monthly
)
select distinct customer_id
from revenue_trend
where revenue_change > 0;

-- insight:
-- Identifies customers whose spending is increasing over time,
-- representing high-upside retention and upsell opportunities.

-- 20. INCREMENTAL REVENUE FROM RETENTION IMPROVEMENT ( ROI QUANTIFICATION )
with customer_value as (
    select
        customer_id,
        count(*) as total_orders,
        sum(order_amount) as lifetime_revenue
    from orders
    group by customer_id
),
retention_stats as (
    select
        count(*) filter (where total_orders > 1) as retained_customers,
        count(*) as total_customers,
        avg(lifetime_revenue) filter (where total_orders > 1) as avg_retained_clv
    from customer_value
)
select
    retained_customers,
    total_customers,
    round(retained_customers * 100.0 / total_customers, 2) as current_retention_percent,
    round(
        (total_customers * 0.05) * avg_retained_clv,
        2
    ) as projected_revenue_uplift_5_percent_retention
from retention_stats;

--insight : 
--A 5% retention lift directly translates into ₹ revenue
--This provides a clear ROI justification for retention-focused initiatives

--21. HIGH - VALUE CUSTOMERS AT RISK ( SAVE vs IGNORE )
with last_orders as (
    select
        customer_id,
        max(order_date) as last_order_date,
        sum(order_amount) as lifetime_revenue
    from orders
    group by customer_id
)
select
    customer_id,
    lifetime_revenue,
    current_date - last_order_date as days_since_last_order
from last_orders
where lifetime_revenue > (
    select avg(lifetime_revenue) from last_orders
)
and current_date - last_order_date > 60
order by lifetime_revenue desc;

--insight :
--These users already proved willingness to spend
--Re-engaging them is cheaper than acquiring new users
--This query directly supports CRM & retention campaigns

--22.FIRST PURCHASE QUALITY -- LONG TERM REVENUE IMPACT 
with first_month as (
    select
        customer_id,
        date_trunc('month', min(order_date)) as first_month
    from orders
    group by customer_id
),
first_month_spend as (
    select
        o.customer_id,
        sum(o.order_amount) as first_month_revenue
    from orders o
    join first_month f
        on o.customer_id = f.customer_id
       and date_trunc('month', o.order_date) = f.first_month
    group by o.customer_id
),
lifetime as (
    select
        customer_id,
        sum(order_amount) as lifetime_revenue
    from orders
    group by customer_id
)
select
    case
        when first_month_revenue < 1000 then 'low_first_spend'
        when first_month_revenue between 1000 and 3000 then 'mid_first_spend'
        else 'high_first_spend'
    end as first_purchase_quality,
    round(avg(l.lifetime_revenue), 2) as avg_lifetime_value
from first_month_spend f
join lifetime l
    on f.customer_id = l.customer_id
group by first_purchase_quality
order by avg_lifetime_value desc;

--insight :
--Strong first-month engagement predicts higher CLV
--Justifies:
    --onboarding optimization
    --first-order incentives
    --early engagement nudges

--23.Revenue Concentration Risk (Stability Check) ?
with ranked_customers as (
    select
        customer_id,
        sum(order_amount) as revenue,
        rank() over (order by sum(order_amount) desc) as rnk
    from orders
    group by customer_id
)
select
    sum(revenue) filter (where rnk <= 10) as top_10_revenue,
    sum(revenue) as total_revenue,
    round(
        sum(revenue) filter (where rnk <= 10)
        * 100.0 / sum(revenue),
        2
    ) as top_10_revenue_percent
from ranked_customers;

--insight :
--High dependence on top customers increases revenue volatility
--Retention of top-tier users is critical for stability
--Diversification should happen via quality retention, not mass acquisition
