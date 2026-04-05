FROM flink:1.18.1-scala_2.12-java11

# Versions pinned for Flink 1.18.x compatibility.
# - Iceberg runtime: built specifically for Flink 1.18
# - Kafka SQL connector: Flink 1.18 line
# - Hadoop client api/runtime + commons-logging: required by Iceberg Hadoop catalog
ARG ICEBERG_FLINK_RUNTIME_VERSION=1.5.2
ARG FLINK_SQL_KAFKA_VERSION=3.1.0-1.18
ARG HADOOP_VERSION=3.3.6
ARG COMMONS_LOGGING_VERSION=1.2
ARG MAVEN_BASE_URL=https://repo.maven.apache.org/maven2

RUN set -eux; \
    mkdir -p /opt/flink/sql /opt/flink/lib; \
    fetch_jar() { \
      jar_name="$1"; \
      jar_url="$2"; \
      echo "Downloading ${jar_name} from ${jar_url}"; \
      code="$(curl -L --retry 5 --retry-all-errors --connect-timeout 15 --max-time 180 \
        -w '%{http_code}' -o "/opt/flink/lib/${jar_name}" "${jar_url}")"; \
      if [ "${code}" != "200" ]; then \
        echo "ERROR: failed to fetch ${jar_name} (HTTP ${code})" >&2; \
        echo "       URL: ${jar_url}" >&2; \
        exit 1; \
      fi; \
      test -s "/opt/flink/lib/${jar_name}"; \
    }; \
    fetch_jar "iceberg-flink-runtime-1.18-${ICEBERG_FLINK_RUNTIME_VERSION}.jar" \
      "${MAVEN_BASE_URL}/org/apache/iceberg/iceberg-flink-runtime-1.18/${ICEBERG_FLINK_RUNTIME_VERSION}/iceberg-flink-runtime-1.18-${ICEBERG_FLINK_RUNTIME_VERSION}.jar"; \
    fetch_jar "flink-sql-connector-kafka-${FLINK_SQL_KAFKA_VERSION}.jar" \
      "${MAVEN_BASE_URL}/org/apache/flink/flink-sql-connector-kafka/${FLINK_SQL_KAFKA_VERSION}/flink-sql-connector-kafka-${FLINK_SQL_KAFKA_VERSION}.jar"; \
    fetch_jar "hadoop-client-api-${HADOOP_VERSION}.jar" \
      "${MAVEN_BASE_URL}/org/apache/hadoop/hadoop-client-api/${HADOOP_VERSION}/hadoop-client-api-${HADOOP_VERSION}.jar"; \
    fetch_jar "hadoop-client-runtime-${HADOOP_VERSION}.jar" \
      "${MAVEN_BASE_URL}/org/apache/hadoop/hadoop-client-runtime/${HADOOP_VERSION}/hadoop-client-runtime-${HADOOP_VERSION}.jar"; \
    fetch_jar "commons-logging-${COMMONS_LOGGING_VERSION}.jar" \
      "${MAVEN_BASE_URL}/commons-logging/commons-logging/${COMMONS_LOGGING_VERSION}/commons-logging-${COMMONS_LOGGING_VERSION}.jar"
