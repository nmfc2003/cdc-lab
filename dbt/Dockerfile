FROM python:3.10-slim

RUN pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir "dbt-spark[session]==1.8.1" "pyspark==3.5.1"

WORKDIR /dbt
