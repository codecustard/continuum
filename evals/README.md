# Evals

Checks that the standard is easy to use correctly, by people and by AI coding agents.

| Eval | Question it answers | Needs |
| --- | --- | --- |
| [agent/](agent/) | Can an agent given only the docs integrate a game correctly? | `sui-move` (or `sui`), Python 3, `jsonschema` |
| [docs-qa/](docs-qa/) | Can a newcomer answer the key questions from the docs alone? | Python 3 |

A failure usually points at the docs or the API, not the agent. Fix those first.

## Agent integration

Five tasks, each in a fresh `game` package next to `continuum` and two fixture games: `koi` (adopts Rules 1 and 4) and `card` (an outside collection that knows nothing about Continuum).

| Task | Rule | The agent writes |
| --- | --- | --- |
| 01-slot | 1 | A "guests charmed" counter on a koi |
| 02-derive | 2 | A mural with verified provenance from a koi |
| 03-record | Records | A shared win record about a card, writable only by the game |
| 04-retire | 4 (draft) | Cooking a koi whole: derive, then retire (freeze) |
| 05-manifest | 3 | `manifest.json` for the finished package |

Scoring per task: it builds, the agent's own tests pass, it wrote a test, hidden behavior tests pass, and static checks (uses `uid_mut`/`derive`, never hands out its witness or slot key, derives before retiring; for the manifest, schema validation and required entries).

```sh
python3 evals/agent/run.py --reference              # reference solutions: must be 5/5
python3 evals/agent/run.py --solutions evals/agent/broken   # common mistakes: must be 0/5
python3 evals/agent/run.py --trials 5 --parallel 4 --label "opus-5.5" \
  --agent 'claude -p "$(cat TASK.md)" --output-format stream-json --verbose --dangerously-skip-permissions'
```

The agent command runs inside the task's `game` folder with `../docs`, `../schema.json` and `../deps/` beside it. Options: `--only 04` for one task, `--k` for pass@k, `--timeout` per trial, `--keep` to keep work dirs.

Each run is saved in `agent/runs/<stamp>/` (gitignored): `summary.json` (commit, label, per-task metrics) and, per trial, `transcript.txt`, the agent's `sources/` and `tests/`, and `result.json`.

Output per task:

| Column | Meaning |
| --- | --- |
| pass@1 | Share of trials that passed every check |
| pass@k | Chance at least one of k tries passes (can it do it at all) |
| pass^k | Chance all k tries pass (can you rely on it) |
| partial | Average share of checks passed |
| errors | Trials where the agent never ran (auth, network); excluded from rates |
| most failed check | Which check to look at first |

pass@k and pass^k use the unbiased estimate from n trials, so run more trials than k. Cost and turns are read from the transcript when the agent prints Claude's `stream-json` result.

`broken/` holds one realistic mistake per task (adding a field twice, `claim` instead of `derive`, an unshared record, retiring before deriving, an incomplete manifest).

## Docs comprehension

Twelve newcomer questions in `docs-qa/questions.jsonl`, each with the key facts a correct answer must contain.

```sh
python3 evals/docs-qa/run.py --self-test            # reference answers pass, wrong ones fail
python3 evals/docs-qa/run.py --model 'claude -p' --trials 3   # model answers from docs only; pass rate per question
python3 evals/docs-qa/run.py --model 'claude -p' --judge 'claude -p'
```

The default judge matches regexes per fact; it's fast and free but strict about wording. `--judge` asks a model instead. Add a question whenever someone asks something the docs didn't answer.

## How we run evals

Following [Anthropic's guide to agent evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents):

- **Several trials per task.** Agents vary run to run; one result says little. Default 5.
- **Clean start every trial.** Fresh temp folder; nothing carries over.
- **Grade the result, not the path.** Hidden tests and checks look at what was built, not how.
- **Code graders first.** Tests, schema and static checks; a model judge only for free-text answers.
- **Prove each task is solvable** (reference solutions pass) **and graders catch mistakes** (`broken/` fails).
- **Read transcripts.** A score isn't trusted until a few failures and passes have been read. A failure can be the grader's fault.
- **0% over many trials means a broken task or grader,** not a weak agent. Check that first.
- **Compare like with like.** Same model, label and trial count; the summary records the commit.
- **Regression vs capability.** Reference and broken runs are regression checks and must stay at 100% / 0%. Agent runs are capability checks; a task that agents always pass can become a regression check.
- **Agents shouldn't see the answers.** With `--dangerously-skip-permissions` an agent can read the whole disk, including `tasks/*/reference` and `hidden`. For scores that count, run the agent in a container or on a machine without this repo checked out, and check transcripts for peeking.

## When to run

- Agent eval: after any change to `continuum`'s public API, the fixtures or `docs/integrating.md` / `standard.md`.
- Docs QA: after any docs rewrite.
- Both before testnet and mainnet publishes.
