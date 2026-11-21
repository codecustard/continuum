# Decisions

Newest first. One line of why each.

## 2026-11-21

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
