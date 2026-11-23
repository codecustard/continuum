# Decisions

Newest first. One line of why each.

## 2026-11-23

- **Fixed the gaps the eval found (#1–#5); manifest task reran at 5/5** (pass^5 1.00, up from 0.00). `witness` takes a list; docs cover unpublished dependency IDs, plain-value slots, caps and omitted `retire`. Summary in `evals/agent/history/2026-11-23-manifest-rerun.json`.
- **First real-agent eval run: pass@1 0.96 (24/25).** Claude Opus 5.5 as a subagent, 5 trials per task, docs only, hidden tests. Summary in `evals/agent/history/2026-11-23-opus-5.5-subagent.json`.

  | Task | pass@1 | pass@5 | pass^5 |
  | --- | --- | --- | --- |
  | 01-slot | 1.00 | 1.00 | 1.00 |
  | 02-derive | 1.00 | 1.00 | 1.00 |
  | 03-record | 1.00 | 1.00 | 1.00 |
  | 04-retire | 1.00 | 1.00 | 1.00 |
  | 05-manifest | 0.80 | 1.00 | 0.00 |

  The one failure: `manifest.json` written to the wrong folder (task wording, #5). Agents' notes found docs/schema gaps that didn't fail checks: one `witness` per manifest (#1, 5 of 5 manifest trials), no guidance for unpublished dependency IDs (#2), deprecated `df::exists_` in snippets (#3), bare-value slot fields (#4). Caveats: same model family as the session that wrote the docs; agents were told, not forced, to stay in their folder; only their final notes were kept, not full transcripts.

- **Registry removed; continuum published to testnet.** Package `0xc2d92a3cea069c9f967f9c913991f2565bf5b073b581c5178f9dba12302796e8`, epoch 1292, one module (`provenance`). Manifests link through MVR metadata. The UpgradeCap is held by the maintainer's dev wallet (`0x3d4f…6365`, a seed-phrase account kept separate from personal wallets); details in `deployments/testnet.json`. Kept upgradeable on testnet; freeze after the two-game proof (roadmap step 10).

## 2026-11-21

- **Evals in the repo.** An agent integration eval (5 tasks, hidden tests, reference and broken solutions) and a docs comprehension eval. Agents will build most integrations, so "can an agent get it right from the docs alone" is the usability test that matters. Failures are treated as docs or API bugs.
- **Draft Rule 4: Retire.** Using up another game's object is central to interop, so it's designed in now: the type's author offers `retire`; retire freezes instead of deleting; the output derives from the input; one `Retired { id, by, into }` event; a `retire` block in the manifest. Named "retire" because it's neutral and covers freeze or delete; games use their own UI words (cook, enshrine).
- **Registry moves to Sui's Move Registry (MVR).** Games put `continuum.manifest` and `continuum.manifest_hash` in their MVR package metadata. Our `registry` module gets removed when continuum is published to testnet. The only thing lost is an on-chain "is registered" check, which is useless because registering is open to anyone; discovery happens off-chain (Hub, Scout, indexers) either way. MVR adds names, source links and version tracking.
- **"Sidecar" renamed to "record"**: plainer word for a game's on-chain record about someone else's object.
- **Docs rewritten for newcomers:** concepts page with one running example, diagrams per rule, FAQ and glossary.
- **Manifest gets an optional `custody` block** (kiosk, locked, transfer policy). Kiosks and sale rules stay each collection's choice, outside the standard.

## 2026-11-20

- **Attested tier deferred.** Design from a real cross-chain case; ship as its own module, not a new `Source` variant.
- **One home chain (Sui) for shared state;** assets stay on their own chains, nothing bridged.
- **Project site on GitHub Pages** from `site/`, deployed by Actions. One static page aimed at builders; neutral wording.
- **Seamless play:** chain only at key moments; zkLogin + sponsored gas by default; records belong to the game so updates need no player signature.

## 2026-11-19

- **Public functions take `&mut TxContext`.** A public signature can't change in an upgrade; `&mut` keeps room.
- **Type names use original package IDs** in records and registry keys, so they survive upgrades.
- **Derive from shared objects is allowed.** Shared objects are public; blocking it adds a rule for nothing.
- **One source per record.** Multi-source objects store several records. Keeps the module small.
- **Kiosk handled client-side** (`borrow_val` → `derive` → `return_val`), not in the module. The standard shouldn't depend on one container.
- **Manifest hash required (32 bytes).** Readers rely on the manifest; a silent swap would break trust.
- **Primitive witnesses rejected.** Anyone can make a `u8` or `vector`.
- **Registry: any Publisher of a package can edit its entry.** Ownership of the package is what matters.
- **No names, approval, fees or removal in the registry.** It's a phone book; trust stays per game.
- **Separate public repo, MIT.** Shared by several games; the code is readable on chain anyway.
- **Work on `main` until something pins a commit;** then branches and PRs.

## 2026-11-15 and earlier

- **Standard = three rules:** open slots, verified provenance, registry + manifest. No shared field names, trust or economy.
- **Collections we don't own get records** (first called sidecars) pointing at the source via `derive` (or CAIP-19 `claim` off-Sui).
- **Minting is permissionless;** an origin stamp separates server-verified from open.
- **Testnet first** with an indexer snapshot for wipes.
