#!/usr/bin/env python3
"""The accounts the switch to live comps with Pro (docs/PLANS.md, 8.7).

    tools/plan_comps.py               their ids, one a line, and how many
    tools/plan_comps.py --mode=test   and each one's plan at Admission in that mode:
    tools/plan_comps.py --mode=live   comped already, or still to comp

Every account made before 29 October 2026 keeps Pro, free and with no end
date, as /plans promised then. Admission gives it as one grant_override a
customer (kind plan, plan pro, no expiry), which only its admin can make,
so this lists whom, and reads back who has it: the ids from the sign-in
service (SUPABASE_URL and SUPABASE_SECRET_KEY, .env or the environment),
never an address, and without the owner's (MASTER_EMAIL), which has every
feature already. --mode asks Admission as the product does, with
ADMISSION_TEST_KEY or ADMISSION_LIVE_KEY: read only, nothing is given here.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from storage_parts import env  # noqa: E402

BEFORE = "2026-10-29T00:00:00"


def accounts() -> list[dict]:
    """Every account of the sign-in service, a page at a time."""
    url, key = env()
    found: list[dict] = []
    page = 1
    while True:
        request = urllib.request.Request(f"{url}/auth/v1/admin/users?page={page}&per_page=1000",
                                         headers={"apikey": key, "authorization": f"Bearer {key}"})
        with urllib.request.urlopen(request, timeout=60) as answer:
            got = json.loads(answer.read())
        batch = got.get("users", []) if isinstance(got, dict) else got
        found += batch
        if len(batch) < 1000:
            return found
        page += 1


def comped(users: list[dict], master: str) -> list[str]:
    """The ids the switch comps: made before 29 October 2026, the owner's not."""
    return sorted(u["id"] for u in users if str(u.get("created_at", "")) < BEFORE
                  and (not master or str(u.get("email") or "").lower() != master.lower()))


def plan_of(customer: str, key: str) -> tuple[str, str]:
    """[customer]'s plan at Admission and where it comes from."""
    request = urllib.request.Request(f"https://admission.sh/v1/customers/{urllib.parse.quote(customer)}",
                                     headers={"authorization": f"Bearer {key}"})
    try:
        with urllib.request.urlopen(request, timeout=30) as answer:
            plan = json.loads(answer.read()).get("plan") or {}
    except urllib.error.HTTPError as problem:
        sys.exit(f"plan_comps: Admission answered {problem.code} for a customer")
    return str(plan.get("key", "")), str(plan.get("source", ""))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mode", choices=["test", "live"])
    args = parser.parse_args(argv)
    ids = comped(accounts(), os.environ.get("MASTER_EMAIL", "").strip())
    if not args.mode:
        print("\n".join(ids))
        print(f"{len(ids)} accounts made before 29 October 2026, the owner's not counted", file=sys.stderr)
        return 0
    key = os.environ.get(f"ADMISSION_{args.mode.upper()}_KEY", "").strip()
    if not key.startswith(f"adm_{args.mode}_"):
        sys.exit(f"plan_comps: no adm_{args.mode}_ key in ADMISSION_{args.mode.upper()}_KEY")
    left = []
    for customer in ids:
        plan, source = plan_of(customer, key)
        given = plan == "pro" and source == "override"
        print(f"{customer}  {plan or '?'} ({source or '?'}){'' if given else '  to comp'}")
        if not given:
            left.append(customer)
    print(f"{args.mode}: {len(ids) - len(left)} given, {len(left)} left of {len(ids)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
