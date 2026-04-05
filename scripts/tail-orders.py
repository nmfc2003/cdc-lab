import argparse
import json
import os
import subprocess
from datetime import datetime


def build_command(mode: str):
    stable_group = "orders-tail-consumer"
    if mode == "replay":
        group = f"orders-tail-replay-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{os.getpid()}"
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
    parser = argparse.ArgumentParser(description="Tail orders CDC events")
    parser.add_argument(
        "--mode",
        choices=["replay", "resume"],
        default="resume",
        help="replay=ephemeral group + from-beginning, resume=stable group + committed offsets",
    )
    args = parser.parse_args()

    cmd, group = build_command(args.mode)
    print(f"starting tail mode={args.mode} group={group}")

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    assert proc.stdout is not None
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
                "consumer_mode": args.mode,
                "consumer_group": group,
                "key": key,
                "op": op,
                "before": before,
                "after": after,
            }, ensure_ascii=False))
        except Exception:
            print(line)


if __name__ == "__main__":
    main()
