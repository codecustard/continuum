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
