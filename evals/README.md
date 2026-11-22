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
python3 evals/agent/run.py --agent 'claude -p "$(cat TASK.md)" --dangerously-skip-permissions'
```

The agent command runs inside the task's `game` folder with `../docs`, `../schema.json` and `../deps/` beside it. Add `--only 04` for one task, `--keep` to inspect work dirs. Results go to `agent/results.json`.

`broken/` holds one realistic mistake per task (adding a field twice, `claim` instead of `derive`, an unshared record, retiring before deriving, an incomplete manifest).

## Docs comprehension

Twelve newcomer questions in `docs-qa/questions.jsonl`, each with the key facts a correct answer must contain.

```sh
python3 evals/docs-qa/run.py --self-test            # reference answers pass, wrong ones fail
python3 evals/docs-qa/run.py --model 'claude -p'    # model answers from docs only
python3 evals/docs-qa/run.py --model 'claude -p' --judge 'claude -p'
```

The default judge matches regexes per fact; it's fast and free but strict about wording. `--judge` asks a model instead. Add a question whenever someone asks something the docs didn't answer.

## When to run

- Agent eval: after any change to `continuum`'s public API, the fixtures or `docs/integrating.md` / `standard.md`.
- Docs QA: after any docs rewrite.
- Both before testnet and mainnet publishes.
