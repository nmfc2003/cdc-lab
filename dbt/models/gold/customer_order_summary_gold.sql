select
  c.customer_id,
  c.full_name,
  c.email,
  c.country,
  count(distinct o.order_id) as total_orders,
  coalesce(sum(case when p.payment_status = 'PAID' then p.amount else 0 end), 0) as total_paid_amount,
  max(o.created_at) as latest_order_ts
from local_iceberg.silver.customers_silver c
left join local_iceberg.silver.orders_silver o on c.customer_id = o.customer_id
left join local_iceberg.silver.payments_silver p on o.order_id = p.order_id
group by 1,2,3,4
