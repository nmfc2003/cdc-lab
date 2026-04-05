# CDC Validation Runbook (Postgres → Debezium → Kafka)

## Purpose

Validate that changes in PostgreSQL are correctly captured via Debezium and emitted to Kafka topic:

```
cdc_lab_pg.public.orders
```

---

## Preconditions

Before running this runbook:

1. Docker stack is running:

   ```
   ./scripts/up.sh
   ```

2. Kafka Connect is healthy:

   ```
   curl http://localhost:8083/connectors/orders-cdc/status | jq .
   ```

3. CDC consumer is running:

   ```
   python3 scripts/orders-to-jsonl.py
   ```

4. Optional live view:

   ```
   python3 scripts/tail-orders.py
   ```

---

## Reset (optional but recommended)

To ensure deterministic results:

```
./scripts/reset_hard.sh
rm -f output/orders_cdc.jsonl
```

Restart stack and consumer after reset.

---

## Test Scenarios

### 1. Basic Insert

```sql
INSERT INTO public.orders (customer_id, status, amount)
VALUES (1001, 'CREATED', 49.90);
```

Expected:

* `op = c`
* `after` populated

---

### 2. Multiple Inserts

```sql
INSERT INTO public.orders (customer_id, status, amount)
VALUES 
  (1002, 'CREATED', 19.99),
  (1003, 'CREATED', 29.99),
  (1004, 'CREATED', 39.99);
```

Expected:

* Multiple `c` events

---

### 3. Update Status

```sql
UPDATE public.orders
SET status = 'PAID',
    updated_at = NOW()
WHERE customer_id = 1001;
```

Expected:

* `op = u`
* `before` and `after` present

---

### 4. Update Numeric Field

```sql
UPDATE public.orders
SET amount = amount * 1.1,
    updated_at = NOW()
WHERE customer_id = 1002;
```

Expected:

* `op = u`
* numeric change visible

---

### 5. Bulk Update

```sql
UPDATE public.orders
SET status = 'PROCESSING',
    updated_at = NOW()
WHERE status = 'CREATED';
```

Expected:

* Multiple `u` events

---

### 6. Delete Single Row

```sql
DELETE FROM public.orders
WHERE customer_id = 1003;
```

Expected:

* `op = d`
* `before` populated

---

### 7. Delete Multiple Rows

```sql
DELETE FROM public.orders
WHERE status = 'PROCESSING';
```

Expected:

* Multiple `d` events

---

### 8. Re-insert Same Entity

```sql
INSERT INTO public.orders (customer_id, status, amount)
VALUES (1003, 'CREATED', 55.55);
```

Expected:

* `op = c`
* new record created

---

### 9. Rapid Mutation Sequence

```sql
INSERT INTO public.orders (customer_id, status, amount)
VALUES (2001, 'CREATED', 10.00);

UPDATE public.orders
SET status = 'PAID', updated_at = NOW()
WHERE customer_id = 2001;

UPDATE public.orders
SET status = 'SHIPPED', updated_at = NOW()
WHERE customer_id = 2001;
```

Expected:

* `c → u → u` sequence

---

### 10. Transactional Consistency

```sql
BEGIN;

INSERT INTO public.orders (customer_id, status, amount)
VALUES (3001, 'CREATED', 99.99);

UPDATE public.orders
SET status = 'PAID', updated_at = NOW()
WHERE customer_id = 3001;

COMMIT;
```

Expected:

* Events appear only after commit

---

### 11. No-op Update

```sql
UPDATE public.orders
SET status = status
WHERE customer_id = 1001;
```

Expected:

* May emit `u` depending on Debezium config

---

### 12. Bulk Insert (Volume Test)

```sql
INSERT INTO public.orders (customer_id, status, amount)
SELECT 
  generate_series(4000, 4010),
  'CREATED',
  random() * 100;
```

Expected:

* Burst of `c` events

---

## Validation Checklist

After running tests, verify:

* Events appear in consumer output
* Correct `op` values: `c`, `u`, `d`
* No unexpected duplicates
* Order of events is preserved
* Delete events contain `before` data
* No replay of old events (offset working)

---

## Notes

* If old data appears → check consumer group / offsets
* If no data appears → check connector status
* If ordering breaks → check Kafka partitions (should be 1 for this lab)

---

## Next Step

Once validated:

→ Move to Flink / Iceberg ingestion pipeline (bronze layer)
