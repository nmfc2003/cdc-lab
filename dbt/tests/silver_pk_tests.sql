-- customers_silver PK checks
select 'customers_silver_null_pk' as test_name where exists (
  select 1 from local_iceberg.silver.customers_silver where customer_id is null
)
union all
select 'customers_silver_duplicate_pk' where exists (
  select customer_id from local_iceberg.silver.customers_silver group by 1 having count(*) > 1
)
union all
select 'orders_silver_null_pk' where exists (
  select 1 from local_iceberg.silver.orders_silver where order_id is null
)
union all
select 'orders_silver_duplicate_pk' where exists (
  select order_id from local_iceberg.silver.orders_silver group by 1 having count(*) > 1
)
union all
select 'payments_silver_null_pk' where exists (
  select 1 from local_iceberg.silver.payments_silver where payment_id is null
)
union all
select 'payments_silver_duplicate_pk' where exists (
  select payment_id from local_iceberg.silver.payments_silver group by 1 having count(*) > 1
)
union all
select 'transactions_silver_null_pk' where exists (
  select 1 from local_iceberg.silver.transactions_silver where transaction_id is null
)
union all
select 'transactions_silver_duplicate_pk' where exists (
  select transaction_id from local_iceberg.silver.transactions_silver group by 1 having count(*) > 1
);
