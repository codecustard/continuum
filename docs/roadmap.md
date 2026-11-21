# Roadmap

The proof is two games sharing one object. The spec is written after, from what worked.

| # | Step | Where | Status |
| --- | --- | --- | --- |
| 1 | `continuum` package: registry + provenance | this repo | ✅ Done (`ed85098`), not yet on testnet |
| 2 | Publish `continuum` to testnet; fill `deployments/testnet.json` | this repo | Next |
| 3 | Koi package: `Koi`, mint, breed, open slot, lock, register | suikoi | Planned |
| 4 | Game's register action mints on testnet | suikoi | Planned |
| 5 | Indexer + snapshot for testnet resets | this repo | Planned |
| 6 | TypeScript SDK: reads, `derive` builder with Kiosk borrow | this repo | Planned |
| 7 | Gang Wars MVP (off-chain results first, sidecars later) | gang-wars | Planned |
| 8 | Second game reads Koi, attaches a slot, derives | tindahan or other | Planned |
| 9 | One-page spec from what the games used | this repo | Planned |
| 10 | Freeze `continuum` (make immutable) after the proof | this repo | Planned |

## Open questions

- Order of tracks: Gang Wars MVP vs Koi package after step 2.
- Collection ID for The Ones.
- Which Koi fields count as shared core.
- Mainnet timing (after review).

## Later: games built without Move (after Gang Wars results)

AI-built and vibe-coded games mostly won't write Move. Idea: a hosted `continuum::records` module.

- A game registers and gets a `GameCap`; the cap stands in for the witness.
- Records derive from any object and hold generic key/value data; the manifest says what keys mean.
- Creating a record needs the player's object and the game's approval in one transaction: the game's server signs a ticket (player, object, game) checked on chain. Later writes need only the cap.
- Registry gets a second table keyed by `GameCap` ID (addable by upgrade).
- Agent-friendly: MCP server, `AGENTS.md`, `llms.txt`, a starter template.

Open, with current leanings:

- **Who holds the GameCap?** Leaning: either; a platform can create and hold caps for its games, and the creator can claim theirs anytime.
- **Records data:** Leaning: key/value only. Games that write Move already get typed data through their own package plus `derive`.
- **Who pays gas at scale?** Leaning: each game or platform sponsors its own gas. Continuum itself holds no funds and pays for nothing.

