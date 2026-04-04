import json
import subprocess
import sys

cmd = [
    "docker", "exec", "-i", "cdc-kafka",
    "/opt/bitnami/kafka/bin/kafka-console-consumer.sh",
    "--bootstrap-server", "localhost:9092",
    "--topic", "cdc_lab_pg.public.orders",
    "--group", "orders-tail-consumer",
    "--property", "print.key=true",
    "--property", "key.separator=|",
]

proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

for line in proc.stdout:
    line = line.strip()
    if not line or "|" not in line:
        print(line)
        continue

    key, value = line.split("|", 1)
    key = key.strip()
    value = value.strip()

    try:
        payload = json.loads(value)
        op = payload.get("payload", {}).get("op")
        before = payload.get("payload", {}).get("before")
        after = payload.get("payload", {}).get("after")
        print(json.dumps({
            "key": key,
            "op": op,
            "before": before,
            "after": after,
        }, ensure_ascii=False))
    except Exception:
        print(line)