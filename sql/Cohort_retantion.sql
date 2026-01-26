-- создание таблицы 
create table online_retail_raw (
invoice Text,
stockcode Text,
description text, 
quantity integer,
invoiceDate TIMESTAMP,
price NUMERIC(10,2),
customer_id text, 
country text
)

create table online_retail_clean as 
select 
	invoice,
	stockcode
	description,
	quantity,
	price,
	(customer_id::numeric)::integer as customer_id,
	country,
	invoiceDate::timestamp as order_ts,
	DATE_TRUNC('month', invoiceDate::timestamp)::date as order_month,
	quantity*price as revenue
from online_retail_raw 
where customer_id is not null
and quantity > 0
and invoice not like 'C%'


--FacKtchek

select count(*) from online_retail_raw 
select count(*) from online_retail_clean

select count(*) filter (where customer_id is null)as null_customer,
count(*) filter (where quantity <=0) as bad_quantity
from online_retail_clean

select * 
from online_retail_clean
limit 10

create table customer_cohort as 
select customer_id,
min(order_ts)as first_order_ts,
DATE_TRUNC('month', MIN(order_ts))::date as cohort_month
from online_retail_clean 
group by customer_id

select *
from customer_cohort
order by first_order_ts
limit 10


DROP TABLE IF EXISTS retention_base;

CREATE TABLE retention_base AS
SELECT
    f.customer_id,
    f.order_ts,
    f.order_month,
    c.cohort_month,
    (
      (DATE_PART('year', f.order_month) - DATE_PART('year', c.cohort_month)) * 12
      + (DATE_PART('month', f.order_month) - DATE_PART('month', c.cohort_month))
    )::int AS cohort_index
FROM online_retail_clean  f
JOIN customer_cohort c
  ON f.customer_id = c.customer_id;


select * from retention_base order by customer_id, order_ts limit 20

select min(cohort_index), max(cohort_index)
from retention_base



CREATE TABLE cohort_size AS
SELECT
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_customers
FROM retention_base
WHERE cohort_index = 0
GROUP BY cohort_month;

select * from cohort_size 



CREATE TABLE cohort_activity AS
SELECT
    cohort_month,
    cohort_index,
    COUNT(DISTINCT customer_id) AS active_customers
FROM retention_base
GROUP BY cohort_month, cohort_index;

select* from cohort_activity limit 20




CREATE TABLE retention_matrix AS
SELECT
    a.cohort_month,
    a.cohort_index,
    a.active_customers,
    s.cohort_customers,
    ROUND(
        a.active_customers::numeric / s.cohort_customers,
        4
    ) AS retention_rate
FROM cohort_activity a
JOIN cohort_size s
  ON a.cohort_month = s.cohort_month
ORDER BY a.cohort_month, a.cohort_index;


select * from retention_matrix limit 20


SELECT *
FROM retention_matrix
WHERE cohort_index = 0
  AND retention_rate <> 1;


SELECT *
FROM retention_matrix
ORDER BY cohort_month, cohort_index

