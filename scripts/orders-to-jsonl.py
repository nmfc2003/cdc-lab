import json
import os
import subprocess
from datetime import datetime

os.makedirs("output", exist_ok=True)
output_path = "output/orders_cdc.jsonl"

cmd = [
    "docker", "exec", "-i", "cdc-kafka",
    "/opt/bitnami/kafka/bin/kafka-console-consumer.sh",
    "--bootstrap-server", "localhost:9092",
    "--topic", "cdc_lab_pg.public.orders",
    "--group", "orders-jsonl-consumer",
    "--property", "print.key=true",
    "--property", "key.separator=|",
]

proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

with open(output_path, "a", encoding="utf-8") as f:
    for line in proc.stdout:
        line = line.strip()
        if not line or "|" not in line:
            continue

        key_raw, value_raw = line.split("|", 1)

        try:
            key_event = json.loads(key_raw.strip())
            value_event = json.loads(value_raw.strip())
        except json.JSONDecodeError:
            continue

        payload = value_event.get("payload", {})
        source = payload.get("source", {})
        op = payload.get("op")

        row = payload.get("after") or payload.get("before") or {}
        key_payload = key_event.get("payload", {})

        minimal = {
            "ingested_at": datetime.utcnow().isoformat() + "Z",
            "op": op,
            "order_id": row.get("order_id") or key_payload.get("order_id"),
            "customer_id": row.get("customer_id"),
            "status": row.get("status"),
            "amount": row.get("amount"),
            "source_ts_ms": source.get("ts_ms"),
            "lsn": source.get("lsn"),
        }

        f.write(json.dumps(minimal, ensure_ascii=False) + "\n")
        f.flush()
        print(minimal)