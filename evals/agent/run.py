#!/usr/bin/env python3
"""Agent integration eval for Continuum.

Each task gives an agent a fresh `game` Move package next to the Continuum
package, two fixture games (koi, card), the docs and the manifest schema.
The agent writes code; we then add hidden tests and score it.

  python3 evals/agent/run.py --reference          # prove harness passes
  python3 evals/agent/run.py --solutions evals/agent/broken   # prove it fails
  python3 evals/agent/run.py --agent 'claude -p "$(cat TASK.md)" --dangerously-skip-permissions'

The agent command runs with cwd = the task's `game` folder.
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile, time
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


def run_task(task, args, keep):
    work = Path(tempfile.mkdtemp(prefix=f"ceval-{task.name}-"))
    game = setup(task, work)
    t0 = time.time()
    log = ""
    if args.agent:
        r = subprocess.run(args.agent, shell=True, cwd=game, capture_output=True, text=True, timeout=args.timeout)
        log = (r.stdout + r.stderr)[-4000:]
    else:
        src = HERE / "tasks" if args.reference else Path(args.solutions).resolve()
        if not place_solution(task, game, src):
            log = "no solution files"
    secs = round(time.time() - t0, 1)
    res = {"task": task.name, "seconds": secs, "checks": []}

    if task.name != "05-manifest":
        ok, out = move("build", game)
        res["checks"].append(("builds", ok, "" if ok else out[-300:]))
        if ok:
            ok, out = move("test", game)
            res["checks"].append(("agent's own tests pass", ok, ""))
            if args.agent and not any((game / "tests").glob("*.move")):
                res["checks"].append(("agent wrote a test", False, ""))
            for h in (task / "hidden").iterdir():
                shutil.copy(h, game / "tests" / h.name)
            ok, out = move("test", game)
            fails = re.findall(r"\[ FAIL\s*\]\s*(\S+)", out)
            res["checks"].append(("hidden tests pass", ok, ", ".join(fails)[:200]))
    res["checks"] += static_checks(task, game)
    res["passed"] = all(c[1] for c in res["checks"])
    res["log"] = log
    if keep:
        res["workdir"] = str(work)
    else:
        shutil.rmtree(work, ignore_errors=True)
    return res


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--reference", action="store_true")
    g.add_argument("--solutions", help="dir with <task>/ subfolders of files")
    g.add_argument("--agent", help="shell command run in the game folder")
    ap.add_argument("--only", help="substring of task names")
    ap.add_argument("--timeout", type=int, default=1200)
    ap.add_argument("--keep", action="store_true", help="keep work dirs")
    ap.add_argument("--out", default=str(HERE / "results.json"))
    args = ap.parse_args()
    if not SUI:
        sys.exit("sui-move or sui not found (set SUI_MOVE)")

    results = []
    for task in TASKS:
        if args.only and args.only not in task.name:
            continue
        r = run_task(task, args, args.keep)
        results.append(r)
        print(f"{'PASS' if r['passed'] else 'FAIL'}  {r['task']}  ({r['seconds']}s)")
        for name, ok, note in r["checks"]:
            print(f"   {'ok ' if ok else 'XX '} {name}{'  — ' + note if note and not ok else ''}")
    n = sum(r["passed"] for r in results)
    print(f"\n{n}/{len(results)} tasks passed")
    Path(args.out).write_text(json.dumps(results, indent=2))
    sys.exit(0 if n == len(results) else 1)


if __name__ == "__main__":
    main()
