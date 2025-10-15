import os, sys, argparse, subprocess, shutil, textwrap

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ENV_PATH = os.path.join(ROOT, ".env")

def load_env(path):
    env = {}
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env

def ensure_psql():
    psql = shutil.which("psql")
    if not psql:
        msg = textwrap.dedent("psql not found.").strip()
        print(msg, file=sys.stderr)
        sys.exit(127)
    return psql

def run_psql(env, db, args, capture=False):
    psql = ensure_psql()
    cmd = [psql,
           "-h", env.get("POSTGRES_HOST", "localhost"),
           "-p", env.get("POSTGRES_PORT", "5432"),
           "-U", env.get("POSTGRES_USER", "postgres"),
           "-d", db, *args]
    run_env = os.environ.copy()
    run_env.update(env)
    if "POSTGRES_PASSWORD" in env:
        run_env["PGPASSWORD"] = env["POSTGRES_PASSWORD"]
    if capture:
        return subprocess.run(cmd, env=run_env, text=True, capture_output=True)
    return subprocess.run(cmd, env=run_env, text=True)

def ensure_db(env, db_name, recreate=False):
    admin_db = env.get("POSTGRES_DB", "postgres")

    if recreate:
        # Terminate + drop
        run_psql(env, admin_db, ["-c",
            f"select pg_terminate_backend(pid) from pg_stat_activity where datname='{db_name}' and pid <> pg_backend_pid();"])
        run_psql(env, admin_db, ["-c", f"drop database if exists {db_name};"])

    # exists?
    chk = run_psql(env, admin_db, ["-tAc", f"select 1 from pg_database where datname='{db_name}';"], capture=True)
    if chk.returncode != 0:
        print(chk.stderr, file=sys.stderr)
        sys.exit(chk.returncode)

    if chk.stdout.strip() == "1":
        return False

    # create
    crt = run_psql(env, admin_db, ["-v", "ON_ERROR_STOP=1", "-c", f"create database {db_name};"])
    if crt.returncode != 0:
        sys.exit(crt.returncode)
    return True

def main():
    parser = argparse.ArgumentParser(
        description="Create <lab>_db and run labs/<lab>/sql/_run_all.sql")
    parser.add_argument("lab", help="lab code, e.g. lab01")
    parser.add_argument("--file", "-f", default=None,
                        help="Path to SQL file (default: labs/<lab>/sql/_run_all.sql)")
    parser.add_argument("--recreate", action="store_true",
                        help="Drop and recreate the lab DB before running SQL")
    parser.add_argument("--vars", nargs="*", default=[],
                        help="Key=Value pairs passed to psql via -v (e.g. --vars SCHEMA=lab01 TZ=UTC)")
    args = parser.parse_args()

    env = load_env(ENV_PATH)
    lab = args.lab
    db_name = f"{lab}_db"

    sql_file = args.file or os.path.join(ROOT, "labs", lab, "sql", "_run_all.sql")
    if not os.path.exists(sql_file):
        print(f"[ERROR] Not found SQL file: {sql_file}", file=sys.stderr)
        sys.exit(2)

    created = ensure_db(env, db_name, recreate=args.recreate)
    print("[LOG]" + ("Created" if created else "Using existing") + f" database: {db_name}")

    v_args = []
    for kv in args.vars:
        if "=" not in kv:
            print(f"--vars expects Key=Value, got: {kv}", file=sys.stderr)
            sys.exit(2)
        v_args += ["-v", kv]

    print(f"[PROCESS] Running: {sql_file}")
    res = run_psql(env, db_name, ["-v", "ON_ERROR_STOP=1", *v_args, "-f", sql_file])
    if res.returncode != 0:
        print("[ERROR] SQL failed", file=sys.stderr)
        sys.exit(res.returncode)
    print(f"[OK] Done: {lab} -> {db_name}")

if __name__ == "__main__":
    main()