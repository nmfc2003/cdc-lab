DO
$$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'debezium') THEN
      CREATE ROLE debezium WITH LOGIN PASSWORD 'dbz' REPLICATION;
   END IF;
END
$$;

GRANT CONNECT ON DATABASE appdb TO debezium;
