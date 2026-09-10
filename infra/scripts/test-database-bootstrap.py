#!/usr/bin/env python3
"""Run the committed database hook against an isolated, disposable PostgreSQL."""
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import subprocess
import time
import uuid

import yaml


def run(*args, input=None, check=True):
    return subprocess.run(args, input=input, text=True, capture_output=True, check=check, timeout=60)


def main():
    image = os.environ.get("ONBOARDING_POSTGRES_IMAGE", "postgres:18-alpine")
    run("docker", "image", "inspect", image)
    name = "devapp-db-bootstrap-test-" + uuid.uuid4().hex[:12]
    manifest = yaml.safe_load((Path(__file__).resolve().parents[1] / "k8s/database-setup-job.yaml").read_text())
    script = manifest["spec"]["template"]["spec"]["containers"][0]["command"][-1]

    def sql(database, statement):
        return run("docker", "exec", "-i", name, "psql", "-X", "-A", "-t",
                   "-v", "ON_ERROR_STOP=1", "-U", "bootstrap_operator", "-d", database,
                   input=statement).stdout.strip()

    def bootstrap():
        return run("docker", "exec", "-i", "-e", "DB_USERNAME=bootstrap_operator",
                   "-e", "DB_PASSWORD=fixture-only", "-e", "PGHOST=127.0.0.1",
                   "-e", "PGDATABASE=postgres", "-e", "PGCONNECT_TIMEOUT=10",
                   name, "sh", "-ec", script)

    run("docker", "run", "--detach", "--network=none", "--name", name,
        "--memory=256m", "--cpus=1", "-e", "POSTGRES_HOST_AUTH_METHOD=trust",
        "-e", "POSTGRES_USER=bootstrap_operator", "-e", "POSTGRES_DB=postgres", image)
    try:
        deadline = time.monotonic() + 60
        while run("docker", "exec", name, "pg_isready", "-h", "127.0.0.1", "-U", "bootstrap_operator",
                  check=False).returncode:
            if time.monotonic() >= deadline:
                raise RuntimeError("Disposable PostgreSQL did not become ready")
            time.sleep(1)
        with ThreadPoolExecutor(max_workers=2) as workers:
            list(workers.map(lambda _index: bootstrap(), range(2)))
        assert sql("postgres", "SELECT count(*) FROM pg_database WHERE datname='devappdb';") == "1"
        sql("postgres", "CREATE ROLE previous_owner; ALTER DATABASE devappdb OWNER TO previous_owner;")
        sql("devappdb", "CREATE TABLE retained_data (id integer PRIMARY KEY, value text); "
                       "INSERT INTO retained_data VALUES (7, 'keep this record');")
        bootstrap()
        bootstrap()
        assert sql("postgres", "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname='devappdb';") == "previous_owner"
        assert sql("devappdb", "SELECT value FROM retained_data WHERE id=7;") == "keep this record"
        print("Database creation, concurrent onboarding, existing ownership and data preservation passed.")
    finally:
        run("docker", "rm", "--force", "--volumes", name)


if __name__ == "__main__":
    main()
