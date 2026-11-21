# Continuum

A shared layer on Sui that lets games build on each other's objects without asking permission.

Site: https://codecustard.github.io/continuum/

Games never call each other. They meet on the same owned objects under three rules:

1. **Open slots.** An object type exposes `uid_mut`. Any game can attach data keyed by its own struct with no public constructor, so only that game can write its slot.
2. **Provenance.** A derived object stores a `Provenance`. It's verified only when made by `continuum::provenance::derive(witness, &source)`, with the source in the same transaction.
3. **Manifest.** Games link a manifest from their package's record in Sui's Move Registry (MVR). The manifest says what fields mean, which types the game makes and reads, and the license for its art and data.

A draft fourth rule, **retire**, covers using up another game's object by freezing it instead of deleting it. See [`docs/standard.md`](docs/standard.md).

Left out on purpose: trust and anti-cheat, balance, economy, and shared field names. Each game decides what it trusts.

## Docs

New here? Start with [`docs/concepts.md`](docs/concepts.md). Everything else is in [`docs/`](docs/).

## Package

`move/continuum`

| Module | What it does |
| --- | --- |
| `provenance` | `derive` makes a verified record from a source object in the same transaction. `claim` makes an unverified record from a CAIP-19 ID (other chains, typed-in IDs). Records name the game that made them and can't be copied or forged. |
| `registry` | *Being removed: manifest links move to Sui's Move Registry (MVR).* One shared `Registry`. Entries keyed by original package ID, holding a manifest URI, its 32-byte hash, and the current package ID after upgrades. Registering and editing need the package's `Publisher`. No names, approval, fees or removal. |

### Deriving

```move
public struct MyGame has drop {}   // witness: no public constructor

let p = continuum::provenance::derive(MyGame {}, &koi, ctx);
// store `p` inside the new object
```

A source in a Kiosk: `kiosk::borrow_val`, then `derive`, then `kiosk::return_val`, all in one transaction.

Readers check `p.is_verified()`, `p.source_is<T>()` and `p.deriver_package()`, then decide whether to trust that package (its MVR record and manifest say who it is).

### Linking your manifest

Create your package's MVR record with your UpgradeCap, then set two keys:

```ts
tx.moveCall({ target: "@mvr/metadata::package_info::set_metadata",
  arguments: [tx.object(packageInfo), tx.pure.string("continuum.manifest"), tx.pure.string("https://…/manifest.json")] });
tx.moveCall({ target: "@mvr/metadata::package_info::set_metadata",
  arguments: [tx.object(packageInfo), tx.pure.string("continuum.manifest_hash"), tx.pure.string("<sha256 hex>")] });
```

The manifest format is in [`manifest/schema.json`](manifest/schema.json).

## Build and test

```sh
cd move/continuum
sui move build
sui move test
```

## Deployments

Current IDs are in [`deployments/`](deployments/). Testnet can be wiped; after a wipe the packages are republished and these files are updated.

## License

MIT
