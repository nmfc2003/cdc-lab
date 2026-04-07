from pyspark.sql import SparkSession

CATALOG = "local_iceberg"
WAREHOUSE = "file:///data/iceberg"
CHECKPOINT_ROOT = "/data/spark-checkpoints"

TABLES = [
    {
        "name": "customers",
        "pk": "customer_id",
        "bronze_cols": "customer_id, full_name, email, country, created_at, updated_at",
        "silver_cols": "customer_id, full_name, email, country, created_at, updated_at, bronze_op, bronze_source_ts_ms, bronze_kafka_event_ts",
        "set_cols": "full_name = s.full_name, email = s.email, country = s.country, created_at = s.created_at, updated_at = s.updated_at, bronze_op = s.bronze_op, bronze_source_ts_ms = s.bronze_source_ts_ms, bronze_kafka_event_ts = s.bronze_kafka_event_ts",
    },
    {
        "name": "orders",
        "pk": "order_id",
        "bronze_cols": "order_id, customer_id, status, CAST(amount AS DECIMAL(12,2)) AS amount, created_at, updated_at",
        "silver_cols": "order_id, customer_id, status, amount, created_at, updated_at, bronze_op, bronze_source_ts_ms, bronze_kafka_event_ts",
        "set_cols": "customer_id = s.customer_id, status = s.status, amount = s.amount, created_at = s.created_at, updated_at = s.updated_at, bronze_op = s.bronze_op, bronze_source_ts_ms = s.bronze_source_ts_ms, bronze_kafka_event_ts = s.bronze_kafka_event_ts",
    },
    {
        "name": "payments",
        "pk": "payment_id",
        "bronze_cols": "payment_id, order_id, customer_id, payment_method, payment_status, CAST(amount AS DECIMAL(12,2)) AS amount, created_at, updated_at",
        "silver_cols": "payment_id, order_id, customer_id, payment_method, payment_status, amount, created_at, updated_at, bronze_op, bronze_source_ts_ms, bronze_kafka_event_ts",
        "set_cols": "order_id = s.order_id, customer_id = s.customer_id, payment_method = s.payment_method, payment_status = s.payment_status, amount = s.amount, created_at = s.created_at, updated_at = s.updated_at, bronze_op = s.bronze_op, bronze_source_ts_ms = s.bronze_source_ts_ms, bronze_kafka_event_ts = s.bronze_kafka_event_ts",
    },
    {
        "name": "transactions",
        "pk": "transaction_id",
        "bronze_cols": "transaction_id, payment_id, order_id, customer_id, txn_type, txn_status, CAST(amount AS DECIMAL(12,2)) AS amount, created_at, updated_at",
        "silver_cols": "transaction_id, payment_id, order_id, customer_id, txn_type, txn_status, amount, created_at, updated_at, bronze_op, bronze_source_ts_ms, bronze_kafka_event_ts",
        "set_cols": "payment_id = s.payment_id, order_id = s.order_id, customer_id = s.customer_id, txn_type = s.txn_type, txn_status = s.txn_status, amount = s.amount, created_at = s.created_at, updated_at = s.updated_at, bronze_op = s.bronze_op, bronze_source_ts_ms = s.bronze_source_ts_ms, bronze_kafka_event_ts = s.bronze_kafka_event_ts",
    },
]

spark = (
    SparkSession.builder.appName("cdc-silver-streaming")
    .config(f"spark.sql.catalog.{CATALOG}", "org.apache.iceberg.spark.SparkCatalog")
    .config(f"spark.sql.catalog.{CATALOG}.type", "hadoop")
    .config(f"spark.sql.catalog.{CATALOG}.warehouse", WAREHOUSE)
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
    .getOrCreate()
)

spark.sql(f"CREATE NAMESPACE IF NOT EXISTS {CATALOG}.silver")


def ensure_silver_table(cfg):
    name = cfg["name"]
    if name == "customers":
        ddl = """
        CREATE TABLE IF NOT EXISTS local_iceberg.silver.customers_silver (
          customer_id BIGINT,
          full_name STRING,
          email STRING,
          country STRING,
          created_at TIMESTAMP,
          updated_at TIMESTAMP,
          bronze_op STRING,
          bronze_source_ts_ms BIGINT,
          bronze_kafka_event_ts TIMESTAMP
        ) USING iceberg
        """
    elif name == "orders":
        ddl = """
        CREATE TABLE IF NOT EXISTS local_iceberg.silver.orders_silver (
          order_id BIGINT,
          customer_id BIGINT,
          status STRING,
          amount DECIMAL(12,2),
          created_at TIMESTAMP,
          updated_at TIMESTAMP,
          bronze_op STRING,
          bronze_source_ts_ms BIGINT,
          bronze_kafka_event_ts TIMESTAMP
        ) USING iceberg
        """
    elif name == "payments":
        ddl = """
        CREATE TABLE IF NOT EXISTS local_iceberg.silver.payments_silver (
          payment_id BIGINT,
          order_id BIGINT,
          customer_id BIGINT,
          payment_method STRING,
          payment_status STRING,
          amount DECIMAL(12,2),
          created_at TIMESTAMP,
          updated_at TIMESTAMP,
          bronze_op STRING,
          bronze_source_ts_ms BIGINT,
          bronze_kafka_event_ts TIMESTAMP
        ) USING iceberg
        """
    else:
        ddl = """
        CREATE TABLE IF NOT EXISTS local_iceberg.silver.transactions_silver (
          transaction_id BIGINT,
          payment_id BIGINT,
          order_id BIGINT,
          customer_id BIGINT,
          txn_type STRING,
          txn_status STRING,
          amount DECIMAL(12,2),
          created_at TIMESTAMP,
          updated_at TIMESTAMP,
          bronze_op STRING,
          bronze_source_ts_ms BIGINT,
          bronze_kafka_event_ts TIMESTAMP
        ) USING iceberg
        """
    spark.sql(ddl)


def upsert_batch(cfg, batch_df, batch_id):
    pk = cfg["pk"]
    name = cfg["name"]
    batch_df.createOrReplaceTempView(f"{name}_bronze_batch")
    latest_sql = f"""
      SELECT {cfg['silver_cols']}
      FROM (
        SELECT
          {cfg['bronze_cols']},
          op AS bronze_op,
          source_ts_ms AS bronze_source_ts_ms,
          kafka_event_ts AS bronze_kafka_event_ts,
          ROW_NUMBER() OVER (PARTITION BY {pk} ORDER BY source_ts_ms DESC, kafka_event_ts DESC) AS rn
        FROM {name}_bronze_batch
        WHERE {pk} IS NOT NULL
      ) t
      WHERE rn = 1
    """
    latest_df = spark.sql(latest_sql)
    latest_df.createOrReplaceTempView(f"{name}_latest_batch")

    spark.sql(
        f"""
        MERGE INTO {CATALOG}.silver.{name}_silver t
        USING {name}_latest_batch s
        ON t.{pk} = s.{pk}
        WHEN MATCHED AND s.bronze_op = 'd' THEN DELETE
        WHEN MATCHED AND s.bronze_op <> 'd' THEN UPDATE SET {cfg['set_cols']}
        WHEN NOT MATCHED AND s.bronze_op <> 'd' THEN INSERT *
        """
    )


queries = []
for cfg in TABLES:
    ensure_silver_table(cfg)
    stream_df = spark.readStream.format("iceberg").load(f"{CATALOG}.bronze.{cfg['name']}_bronze")
    q = (
        stream_df.writeStream.trigger(processingTime="10 seconds")
        .option("checkpointLocation", f"{CHECKPOINT_ROOT}/{cfg['name']}_silver")
        .foreachBatch(lambda df, bid, c=cfg: upsert_batch(c, df, bid))
        .start()
    )
    queries.append(q)

for query in queries:
    query.awaitTermination()
