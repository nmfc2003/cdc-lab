with latest_txn as (
  select order_id, txn_status,
         row_number() over (partition by order_id order by bronze_source_ts_ms desc, bronze_kafka_event_ts desc) as rn
  from local_iceberg.silver.transactions_silver
)
select
  o.order_id,
  o.customer_id,
  o.status as order_status,
  o.amount as order_amount,
  p.payment_status as latest_payment_status,
  t.txn_status as latest_transaction_status,
  o.created_at as order_created_at
from local_iceberg.silver.orders_silver o
left join local_iceberg.silver.payments_silver p on o.order_id = p.order_id
left join latest_txn t on o.order_id = t.order_id and t.rn = 1
