import argparse
import json
import os
import subprocess
from datetime import datetime


def build_command(mode: str):
    stable_group = "orders-jsonl-consumer"
    if mode == "replay":
        group = f"orders-jsonl-replay-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{os.getpid()}"
    else:
        group = stable_group

    cmd = [
        "docker", "exec", "-i", "cdc-kafka",
        "/opt/bitnami/kafka/bin/kafka-console-consumer.sh",
        "--bootstrap-server", "localhost:9092",
        "--topic", "cdc_lab_pg.public.orders",
        "--group", group,
        "--property", "print.key=true",
        "--property", "key.separator=|",
    ]

    if mode == "replay":
        cmd.append("--from-beginning")

    return cmd, group


def main():
    parser = argparse.ArgumentParser(description="Consume orders CDC topic into output/orders_cdc.jsonl")
    parser.add_argument(
        "--mode",
        choices=["replay", "resume"],
        default="replay",
        help="replay=ephemeral group + from-beginning, resume=stable group + committed offsets",
    )
    args = parser.parse_args()

    os.makedirs("output", exist_ok=True)
    output_path = "output/orders_cdc.jsonl"

    cmd, group = build_command(args.mode)
    print(f"starting consumer mode={args.mode} group={group}")

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    with open(output_path, "a", encoding="utf-8") as f:
        assert proc.stdout is not None
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
                "consumer_mode": args.mode,
                "consumer_group": group,
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


if __name__ == "__main__":
    main()
