#!/usr/bin/env python3
"""Docs comprehension eval: can a model answer newcomer questions from docs/ alone?

  python3 evals/docs-qa/run.py --self-test
  python3 evals/docs-qa/run.py --answers my_answers.jsonl
  python3 evals/docs-qa/run.py --model 'claude -p'                 # prompt on stdin
  python3 evals/docs-qa/run.py --model 'claude -p' --judge 'claude -p'

Each question lists key facts. Default judge: a fact counts if any of its
regexes match the answer. With --judge, a model decides instead (stdin
prompt, must reply YES or NO). A question passes if every fact is present.
A failing question usually means the docs are unclear, not the model.
"""
import argparse, json, re, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOCS = HERE.parent.parent / "docs"


def load(p):
    return [json.loads(l) for l in Path(p).read_text().splitlines() if l.strip()]


def docs_text():
    return "\n\n".join(f"=== {p.name} ===\n{p.read_text()}" for p in sorted(DOCS.glob("*.md")))


def call(cmd, prompt, timeout=300):
    r = subprocess.run(cmd, shell=True, input=prompt, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip()[-300:] or r.stdout.strip()[-300:])
    return r.stdout.strip()


def ask(cmd, docs, q):
    return call(cmd, f"Answer using only these docs. Two to four sentences.\n\n{docs}\n\nQuestion: {q}\n")


def has_fact(fact, answer, judge):
    if judge:
        out = call(judge, f"Answer: {answer}\n\nDoes the answer state this fact (same meaning, any wording)? "
                          f"Fact: {fact['fact']}\nReply YES or NO only.")
        return out.strip().upper().startswith("YES")
    return any(re.search(m, answer, re.I) for m in fact["match"])


def score(questions, answers, judge=None):
    rows = []
    for q in questions:
        a = answers.get(q["id"], "")
        hits = [(f["fact"], has_fact(f, a, judge)) for f in q["facts"]]
        rows.append({"id": q["id"], "passed": all(h for _, h in hits), "facts": hits, "answer": a})
    return rows


def report(rows):
    for r in rows:
        print(f"{'PASS' if r['passed'] else 'FAIL'}  {r['id']}")
        for f, ok in r["facts"]:
            if not ok:
                print(f"   missing: {f}")
    n = sum(r["passed"] for r in rows)
    print(f"\n{n}/{len(rows)} questions passed")
    return n


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--self-test", action="store_true")
    g.add_argument("--answers")
    g.add_argument("--model")
    ap.add_argument("--judge")
    ap.add_argument("--out", default=str(HERE / "results.json"))
    a = ap.parse_args()
    qs = load(HERE / "questions.jsonl")

    if a.self_test:
        ref = {x["id"]: x["answer"] for x in load(HERE / "reference_answers.jsonl")}
        bad = {x["id"]: x["answer"] for x in load(HERE / "wrong_answers.jsonl")}
        r1, r2 = score(qs, ref, a.judge), score(qs, bad, a.judge)
        print("reference answers:"); n1 = report(r1)
        print("\nwrong answers:"); n2 = sum(r["passed"] for r in r2)
        for r in r2:
            if r["passed"]:
                print(f"   wrongly passed: {r['id']}")
        print(f"{n2}/{len(r2)} wrongly passed")
        ok = n1 == len(qs) and n2 == 0
        print("\nself-test", "OK" if ok else "FAILED")
        sys.exit(0 if ok else 1)

    if a.answers:
        answers = {x["id"]: x["answer"] for x in load(a.answers)}
    else:
        d = docs_text()
        answers = {}
        for q in qs:
            answers[q["id"]] = ask(a.model, d, q["question"])
            print(f"asked {q['id']}", file=sys.stderr)
    rows = score(qs, answers, a.judge)
    n = report(rows)
    Path(a.out).write_text(json.dumps(rows, indent=2))
    sys.exit(0 if n == len(rows) else 1)


if __name__ == "__main__":
    main()
