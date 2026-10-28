#!/usr/bin/env python3
"""Who would use a paid plan: the counts from /plans' interest form.

    tools/plan_interest.py                  how many a plan, monthly or yearly
    tools/plan_interest.py --of EMAIL       what is kept for one address, to answer its owner
    tools/plan_interest.py --forget EMAIL   one address's entries deleted, when its owner asks

The form (web/plans.html, api/plans.js) keeps an address, the plan, monthly
or yearly and a line (supabase/plan_interest.sql). This reads it as the
server does, with SUPABASE_URL and SUPABASE_SECRET_KEY from .env or the
environment, through the file's own functions: the counts never name an
address, and no address is printed but the one asked about. Resend's test
addresses (@resend.dev, the site's checks) are counted apart.

The research's bar (price274, section 7) is 30 paid founding annuals for
go, under 10 after 60 days to stop. These are people saying they would use
a plan, not pre-orders: a step before that bar, not the bar.
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from storage_parts import env  # noqa: E402

GO, STOP = 30, 10


def ask(name: str, body: dict) -> object:
    url, key = env()
    request = urllib.request.Request(
        f"{url}/rest/v1/rpc/{name}", data=json.dumps(body).encode(), method="POST",
        headers={"apikey": key, "authorization": f"Bearer {key}", "content-type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=30) as answer:
            return json.loads(answer.read() or b"null")
    except urllib.error.HTTPError as problem:
        if problem.code == 404:
            sys.exit("plan_interest: supabase/plan_interest.sql is not applied to this project yet")
        sys.exit(f"plan_interest: {name} answered {problem.code}")


def counts() -> None:
    rows = ask("plan_interest_counts", {})
    assert isinstance(rows, list)
    if not rows:
        print("nobody yet")
    for plan in ("plus", "creator"):
        mine = [row for row in rows if row["plan"] == plan]
        people = sum(int(row["people"]) for row in mine)
        by = ", ".join(f"{row['billing']} {row['people']}" for row in mine)
        print(f"{plan:8} {people:4}  ({by or 'none'})")
    people = sum(int(row["people"]) for row in rows)
    tests = sum(int(row["tests"]) for row in rows)
    print(f"{'all':8} {people:4}  entries, an address once a plan; {tests} more from the checks' test addresses")
    print(f"the research's bar: {GO} paid founding annuals = go, under {STOP} after 60 days = stop. "
          "These are sign-ups of interest, not pre-orders.")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--of", metavar="EMAIL")
    parser.add_argument("--forget", metavar="EMAIL")
    args = parser.parse_args(argv)
    if args.of:
        rows = ask("plan_interest_of", {"p_email": args.of})
        assert isinstance(rows, list)
        for row in rows:
            print(f"{row['plan']:8} {row['billing']:8} since {row['created_at'][:10]}, "
                  f"changed {row['updated_at'][:10]}  {row['note']!r}")
        if not rows:
            print("nothing kept for that address")
        return 0
    if args.forget:
        print(f"deleted {ask('plan_interest_forget', {'p_email': args.forget})} entries of that address")
        return 0
    counts()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
