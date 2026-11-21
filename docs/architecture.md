# Architecture

## Layers

```
Discovery apps               read registry + indexer
  │
Games (Suikoi, Gang Wars, …) own their packages, clients, servers
  │
Continuum package            registry · provenance
  │
Sui objects                  owned by players
```

Games never call each other. They meet on the same owned objects.

## Package: `move/continuum`

| Module | Objects | Entry points | Events |
| --- | --- | --- | --- |
| `provenance` | `Provenance` (store, drop), `Source` enum | `derive`, `claim` | `Derived`, `Claimed` |
| `registry` | `Registry` (shared), `Entry`, `Manifest` | `register`, `update_manifest`, `set_latest` | `Registered`, `ManifestUpdated`, `LatestSet` |

Type names use **original package IDs** everywhere, so records and registry keys stay stable across upgrades.

## Who signs what

| Action | Signer | How often |
| --- | --- | --- |
| Read any object | Nobody | Always free |
| `derive` from an owned object | Its owner | At on-chain moments only (mint, breed, enlist) |
| Write to your own sidecar | Your game | Every update, no player prompt |
| Attach a slot via `uid_mut` | The object's owner | Rare |
| `register` / `update_manifest` | Package publisher | Once, then on manifest changes |

## Keeping play seamless

- **Chain only for moments that matter.** Moment-to-moment play stays off-chain; anything the client can fake earns only off-chain rewards.
- **zkLogin + sponsored gas.** Players sign in with a social account; a short-lived key signs in the background and the game pays gas. No wallet popups, no gas token needed.
- **One transaction per moment.** Programmable transactions batch steps, e.g. Kiosk `borrow_val` → `derive` → create sidecar → `return_val` is one approval.
- **Sidecars belong to the game.** After a one-time enlist, the game writes results without asking the player.

Wallet users see one prompt per on-chain moment; zkLogin users see none.

## Across chains

Assets stay on their own chain. Shared state (records, slots, lineage) lives on one home chain, Sui. Nothing is bridged.

| A game wants to | Game on Sui | Game on another chain |
| --- | --- | --- |
| Read objects and lineage | RPC or SDK | Same API, needs nothing |
| Write shared state | Its own Move package | Through a hosted records path; someone else sponsors gas, so the game never holds SUI |
| Prove a player owns an item | `derive` with the item in the transaction | Attested by a known signer, or claimed |

**Levels of certainty:**

- **Verified:** the source object was in the transaction. Sui only.
- **Attested:** a known signer read the other chain and vouched for ownership. Any chain. *(planned)*
- **Claimed:** an ID was typed in. Any chain.

**Collections on other chains:**

1. The player links a wallet on that chain to their Sui account by signing once. *(planned: account link record)*
2. An attester checks ownership on that chain and signs it.
3. A sidecar on Sui points at the item's CAIP-19 ID and holds the game's data.
4. Ownership can change on the other chain, so games re-check when it matters.

**Why one home chain:** one place to read, one family tree. The rules and CAIP-19 IDs don't depend on Sui, so a move is possible later.

## Off-chain pieces (planned)

- **Indexer:** follows `Derived`, `Claimed`, `Registered` and game events; builds lineage; keeps the testnet snapshot.
- **TypeScript SDK:** read helpers and transaction builders (`derive` with Kiosk borrow, slot reads).
- **A discovery hub, MCP server and API:** discovery for people and agents.

## Testnet resets

1. The indexer keeps every game object as JSON.
2. After a wipe, republish the packages.
3. Re-mint from the snapshot to the same owners.
4. Re-register and update [`deployments/`](../deployments/).
