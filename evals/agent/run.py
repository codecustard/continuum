#!/usr/bin/env python3
"""Agent integration eval for Continuum.

Each task gives an agent a fresh `game` Move package next to the Continuum
package, two fixture games (koi, card), the docs and the manifest schema.
The agent writes code; we then add hidden tests and score it.

  python3 evals/agent/run.py --reference          # prove harness passes
  python3 evals/agent/run.py --solutions evals/agent/broken   # prove it fails
  python3 evals/agent/run.py --trials 5 --parallel 4 \
      --agent 'claude -p "$(cat TASK.md)" --output-format stream-json --verbose --dangerously-skip-permissions'

The agent command runs with cwd = the task's `game` folder. Every trial starts
from a clean copy. Each run is saved under runs/<stamp>/ with per-trial
transcripts and the agent's files, plus summary.json.
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile, time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from math import comb
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
TASKS = sorted(p for p in (HERE / "tasks").iterdir() if p.is_dir())
SUI = os.environ.get("SUI_MOVE") or shutil.which("sui-move") or shutil.which("sui")


def move(cmd, pkg):
    args = [SUI] + (["move"] if SUI.endswith("/sui") else []) + [cmd, "--path", str(pkg)]
    r = subprocess.run(args, capture_output=True, text=True, timeout=600)
    return r.returncode == 0, (r.stdout + r.stderr)[-4000:]


def setup(task, work):
    deps = work / "deps"
    shutil.copytree(REPO / "move" / "continuum", deps / "continuum", ignore=shutil.ignore_patterns("build", "tests"))
    for f in ("koi", "card"):
        shutil.copytree(HERE.parent / "fixtures" / f, deps / f, ignore=shutil.ignore_patterns("build"))
    shutil.copytree(REPO / "docs", work / "docs")
    shutil.copy(REPO / "manifest" / "schema.json", work / "schema.json")
    game = work / "game"
    shutil.copytree(HERE / "template", game)
    shutil.copy(task / "TASK.md", game / "TASK.md")
    if task.name == "05-manifest":  # finished package to describe
        for t in TASKS[:4]:
            for f in (t / "reference").iterdir():
                shutil.copy(f, game / "sources" / f.name)
    return game


def place_solution(task, game, src_dir):
    src = src_dir / task.name if (src_dir / task.name).is_dir() else src_dir
    if src_dir == HERE / "tasks":
        src = task / "reference"
    found = False
    for f in src.iterdir() if src.is_dir() else []:
        dest = game / ("manifest.json" if f.suffix == ".json" else f"sources/{f.name}")
        shutil.copy(f, dest)
        found = True
    return found


def static_checks(task, game):
    spec = json.loads((task / "checks.json").read_text())
    out = []
    for rel in spec["files"]:
        if not (game / rel).exists():
            return [("file " + rel, False, "missing")]
    if task.name == "05-manifest":
        return manifest_checks(spec["manifest"], game)
    src = "\n".join((game / rel).read_text() for rel in spec["files"])
    code = re.sub(r"//.*", "", src)
    for needle in spec.get("require", []):
        out.append((f"uses {needle}", needle in code, ""))
    for name in spec.get("forbid_ctor", []):
        leak = re.search(r"public\s+fun\s+\w+[^{;]*\)\s*:\s*[^{]*\b" + name + r"\b", code)
        out.append((f"{name} not handed out", leak is None, leak.group(0)[:80] if leak else ""))
    for a, b in spec.get("order", []):
        ia, ib = code.find(a), code.find(b)
        out.append((f"{a} before {b}", 0 <= ia < ib, ""))
    return out


def manifest_checks(spec, game):
    import jsonschema
    out = []
    try:
        m = json.loads((game / "manifest.json").read_text())
    except Exception as e:
        return [("manifest parses", False, str(e)[:80])]
    try:
        jsonschema.validate(m, json.loads((REPO / "manifest" / "schema.json").read_text()))
        out.append(("matches schema", True, ""))
    except jsonschema.ValidationError as e:
        out.append(("matches schema", False, e.message[:80]))
    types = [t.get("type", "") for t in m.get("types", [])]
    for t in spec["types"]:
        out.append((f"type {t}", any(x.endswith(t) for x in types), ""))
    slots = m.get("slots", [])
    for k in spec["slots_key"]:
        out.append((f"slot {k}", any(s.get("key", "").endswith(k) for s in slots), ""))
    for on in spec["slots_on"]:
        out.append((f"slot on {on}", any(s.get("on", "").endswith(on) for s in slots), ""))
    for r in spec["reads"]:
        out.append((f"reads {r}", any(x.endswith(r) for x in m.get("reads", [])), ""))
    lic = m.get("license", {})
    out.append(("license CC0", lic.get("art") == "CC0-1.0" and lic.get("data") == "CC0-1.0", ""))
    return out


def parse_usage(log):
    """Pull cost/turns/tokens from a claude stream-json `result` line, if any."""
    for line in reversed(log.splitlines()):
        line = line.strip()
        if line.startswith("{") and '"type":"result"' in line.replace(" ", ""):
            try:
                r = json.loads(line)
            except ValueError:
                continue
            u = r.get("usage") or {}
            return {"cost_usd": r.get("total_cost_usd"), "turns": r.get("num_turns"),
                    "input_tokens": u.get("input_tokens"), "output_tokens": u.get("output_tokens")}
    return {}


def run_trial(task, trial, args, run_dir):
    work = Path(tempfile.mkdtemp(prefix=f"ceval-{task.name}-{trial}-"))
    game = setup(task, work)
    before = {p.relative_to(game) for p in game.rglob("*") if p.is_file()}
    t0 = time.time()
    log, status = "", "graded"
    if args.agent:
        try:
            r = subprocess.run(args.agent, shell=True, cwd=game, capture_output=True, text=True, timeout=args.timeout)
            log = r.stdout + "\n--- stderr ---\n" + r.stderr
            changed = {p.relative_to(game) for p in game.rglob("*") if p.is_file() and "build" not in p.parts} - before
            if r.returncode != 0 and not changed:
                status = "error"  # agent never ran (auth, network, crash): not a task failure
        except subprocess.TimeoutExpired as e:
            log = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
            log += "\n--- timed out ---"
    else:
        src = HERE / "tasks" if args.reference else Path(args.solutions).resolve()
        if not place_solution(task, game, src):
            log = "no solution files"
    res = {"task": task.name, "trial": trial, "status": status,
           "agent_seconds": round(time.time() - t0, 1), "usage": parse_usage(log), "checks": []}

    if status == "graded":
        if task.name != "05-manifest":
            ok, out = move("build", game)
            res["checks"].append(("builds", ok, "" if ok else out[-300:]))
            if ok:
                ok, out = move("test", game)
                res["checks"].append(("agent's own tests pass", ok, ""))
                if args.agent:
                    res["checks"].append(("agent wrote a test", any((game / "tests").glob("*.move")), ""))
                for h in (task / "hidden").iterdir():
                    shutil.copy(h, game / "tests" / h.name)
                ok, out = move("test", game)
                fails = re.findall(r"\[ FAIL\s*\]\s*(\S+)", out)
                res["checks"].append(("hidden tests pass", ok, ", ".join(fails)[:200]))
        res["checks"] += static_checks(task, game)
    res["passed"] = status == "graded" and all(c[1] for c in res["checks"])
    res["partial"] = round(sum(c[1] for c in res["checks"]) / len(res["checks"]), 2) if res["checks"] else 0.0

    # Keep the transcript and what the agent produced, for reading failures.
    tdir = run_dir / task.name / f"trial-{trial}"
    tdir.mkdir(parents=True, exist_ok=True)
    (tdir / "transcript.txt").write_text(log)
    for sub in ("sources", "tests"):
        if (game / sub).exists():
            shutil.copytree(game / sub, tdir / sub, dirs_exist_ok=True)
    if (game / "manifest.json").exists():
        shutil.copy(game / "manifest.json", tdir / "manifest.json")
    (tdir / "result.json").write_text(json.dumps(res, indent=2))
    if args.keep:
        res["workdir"] = str(work)
    else:
        shutil.rmtree(work, ignore_errors=True)
    return res


def pass_at_k(n, c, k):
    """Chance at least one of k trials passes (unbiased estimate from n trials, c passes)."""
    return 1.0 if n - c < k else 1 - comb(n - c, k) / comb(n, k)


def pass_hat_k(n, c, k):
    """Chance all k trials pass (unbiased estimate)."""
    return comb(c, k) / comb(n, k) if k <= n else 0.0


def summarize(task, trials, k):
    graded = [t for t in trials if t["status"] == "graded"]
    n, c = len(graded), sum(t["passed"] for t in graded)
    fails = {}
    for t in graded:
        for name, ok, _ in t["checks"]:
            if not ok:
                fails[name] = fails.get(name, 0) + 1
    costs = [t["usage"].get("cost_usd") for t in graded if t["usage"].get("cost_usd") is not None]
    secs = [t["agent_seconds"] for t in graded]
    return {
        "task": task, "trials": len(trials), "graded": n, "errors": len(trials) - n, "passes": c,
        "pass@1": round(c / n, 2) if n else None,
        f"pass@{k}": round(pass_at_k(n, c, k), 2) if n >= k else None,
        f"pass^{k}": round(pass_hat_k(n, c, k), 2) if n >= k else None,
        "partial": round(sum(t["partial"] for t in graded) / n, 2) if n else None,
        "failed_checks": dict(sorted(fails.items(), key=lambda x: -x[1])),
        "mean_seconds": round(sum(secs) / n, 1) if n else None,
        "mean_cost_usd": round(sum(costs) / len(costs), 4) if costs else None,
    }


def git_commit():
    r = subprocess.run(["git", "-C", str(REPO), "rev-parse", "--short", "HEAD"], capture_output=True, text=True)
    dirty = subprocess.run(["git", "-C", str(REPO), "status", "--porcelain", "docs", "move", "evals/fixtures"],
                           capture_output=True, text=True).stdout.strip()
    return r.stdout.strip() + ("-dirty" if dirty else "")


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--reference", action="store_true")
    g.add_argument("--solutions", help="dir with <task>/ subfolders of files")
    g.add_argument("--agent", help="shell command run in the game folder")
    ap.add_argument("--trials", type=int, help="trials per task (default 5 with --agent, else 1)")
    ap.add_argument("--k", type=int, help="k for pass@k / pass^k (default: --trials, max 5)")
    ap.add_argument("--parallel", type=int, default=1, help="trials run at once")
    ap.add_argument("--only", help="substring of task names")
    ap.add_argument("--timeout", type=int, default=1200, help="seconds per agent trial")
    ap.add_argument("--label", default="", help="free text saved with the run, e.g. model name")
    ap.add_argument("--keep", action="store_true", help="keep work dirs")
    args = ap.parse_args()
    if not SUI:
        sys.exit("sui-move or sui not found (set SUI_MOVE)")
    trials = args.trials or (5 if args.agent else 1)
    k = args.k or min(trials, 5)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")[:-3]
    run_dir = HERE / "runs" / stamp
    run_dir.mkdir(parents=True)
    tasks = [t for t in TASKS if not args.only or args.only in t.name]
    jobs = [(t, i) for t in tasks for i in range(1, trials + 1)]
    with ThreadPoolExecutor(max_workers=args.parallel) as ex:
        results = list(ex.map(lambda j: run_trial(j[0], j[1], args, run_dir), jobs))

    summary = [summarize(t.name, [r for r in results if r["task"] == t.name], k) for t in tasks]
    print(f"{'task':<13}{'pass@1':>8}{'pass@'+str(k):>8}{'pass^'+str(k):>8}{'partial':>9}{'errors':>8}  most failed check")
    for s in summary:
        f = lambda v: "-" if v is None else f"{v:.2f}"
        top = next(iter(s["failed_checks"].items()), ("", 0))
        print(f"{s['task']:<13}{f(s['pass@1']):>8}{f(s[f'pass@{k}']):>8}{f(s[f'pass^{k}']):>8}"
              f"{f(s['partial']):>9}{s['errors']:>8}  {top[0] + (' ×' + str(top[1]) if top[1] else '')}")
    graded = [r for r in results if r["status"] == "graded"]
    overall = round(sum(r["passed"] for r in graded) / len(graded), 2) if graded else None
    errors = len(results) - len(graded)
    print(f"\noverall pass@1 {overall}  ({len(graded)} graded, {errors} errors)  -> {run_dir}")
    if errors:
        print("errors are trials where the agent never ran; see transcript.txt")
    meta = {"stamp": stamp, "commit": git_commit(), "label": args.label,
            "mode": "agent" if args.agent else ("reference" if args.reference else "solutions"),
            "agent": args.agent, "trials": trials, "k": k, "overall_pass@1": overall, "tasks": summary}
    (run_dir / "summary.json").write_text(json.dumps(meta, indent=2))
    sys.exit(0 if graded and overall == 1.0 and not errors else 1)


if __name__ == "__main__":
    main()
