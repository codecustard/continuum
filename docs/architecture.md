# Architecture

## Layers

```
Remix Hub (discovery)        reads registry + indexer
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

## Off-chain pieces (planned)

- **Indexer:** follows `Derived`, `Claimed`, `Registered` and game events; builds lineage; keeps the testnet snapshot.
- **TypeScript SDK:** read helpers and transaction builders (`derive` with Kiosk borrow, slot reads).
- **Remix Hub, MCP server and API:** discovery for people and agents.

## Testnet resets

1. The indexer keeps every game object as JSON.
2. After a wipe, republish the packages.
3. Re-mint from the snapshot to the same owners.
4. Re-register and update [`deployments/`](../deployments/).
