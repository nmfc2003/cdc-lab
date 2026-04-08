with orders_daily as (
  select cast(created_at as date) as revenue_date, count(*) as total_orders
  from local_iceberg.silver.orders_silver
  group by 1
),
payments_daily as (
  select cast(created_at as date) as revenue_date, count(*) as total_payments
  from local_iceberg.silver.payments_silver
  group by 1
),
txns_daily as (
  select cast(created_at as date) as revenue_date,
         count(case when txn_status = 'SUCCESS' then 1 end) as total_successful_transactions,
         coalesce(sum(case when txn_status = 'SUCCESS' then amount else 0 end), 0) as gross_revenue
  from local_iceberg.silver.transactions_silver
  group by 1
)
select
  coalesce(o.revenue_date, p.revenue_date, t.revenue_date) as revenue_date,
  coalesce(o.total_orders, 0) as total_orders,
  coalesce(p.total_payments, 0) as total_payments,
  coalesce(t.total_successful_transactions, 0) as total_successful_transactions,
  coalesce(t.gross_revenue, 0) as gross_revenue
from orders_daily o
full outer join payments_daily p on o.revenue_date = p.revenue_date
full outer join txns_daily t on coalesce(o.revenue_date, p.revenue_date) = t.revenue_date
