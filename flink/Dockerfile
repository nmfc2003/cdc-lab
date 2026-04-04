FROM flink:1.18.1-scala_2.12-java11

ARG ICEBERG_VERSION=1.5.2
ARG FLINK_KAFKA_VERSION=3.1.0-1.18
ARG HADOOP_VERSION=3.3.6

RUN set -eux; \
    mkdir -p /opt/flink/sql /opt/flink/usrlib; \
    curl -fsSL -o /opt/flink/lib/iceberg-flink-runtime-1.18-${ICEBERG_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-flink-runtime-1.18/${ICEBERG_VERSION}/iceberg-flink-runtime-1.18-${ICEBERG_VERSION}.jar; \
    curl -fsSL -o /opt/flink/lib/flink-sql-connector-kafka-${FLINK_KAFKA_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/${FLINK_KAFKA_VERSION}/flink-sql-connector-kafka-${FLINK_KAFKA_VERSION}.jar; \
    curl -fsSL -o /opt/flink/lib/hadoop-common-${HADOOP_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/${HADOOP_VERSION}/hadoop-common-${HADOOP_VERSION}.jar; \
    curl -fsSL -o /opt/flink/lib/hadoop-hdfs-${HADOOP_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-hdfs/${HADOOP_VERSION}/hadoop-hdfs-${HADOOP_VERSION}.jar; \
    curl -fsSL -o /opt/flink/lib/hadoop-mapreduce-client-core-${HADOOP_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-mapreduce-client-core/${HADOOP_VERSION}/hadoop-mapreduce-client-core-${HADOOP_VERSION}.jar
