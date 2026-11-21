# Continuum

A shared layer on Sui that lets games build on each other's objects without asking permission.

Games never call each other. They meet on the same owned objects under three rules:

1. **Open slots.** An object type exposes `uid_mut`. Any game can attach data keyed by its own struct with no public constructor, so only that game can write its slot.
2. **Provenance.** A derived object stores a `Provenance`. It's verified only when made by `continuum::provenance::derive(witness, &source)`, with the source in the same transaction.
3. **Registry and manifest.** Games register on chain by package ID. The manifest says what fields mean, which types the game makes and reads, and the license for its art and data.

Left out on purpose: trust and anti-cheat, balance, economy, and shared field names. Each game decides what it trusts.

## Docs

Standard, architecture, integration guide, decisions and roadmap: [`docs/`](docs/).

## Package

`move/continuum`

| Module | What it does |
| --- | --- |
| `provenance` | `derive` makes a verified record from a source object in the same transaction. `claim` makes an unverified record from a CAIP-19 ID (other chains, typed-in IDs). Records name the game that made them and can't be copied or forged. |
| `registry` | One shared `Registry`. Entries keyed by original package ID, holding a manifest URI, its 32-byte hash, and the current package ID after upgrades. Registering and editing need the package's `Publisher`. No names, approval, fees or removal. |

### Deriving

```move
public struct MyGame has drop {}   // witness: no public constructor

let p = continuum::provenance::derive(MyGame {}, &koi, ctx);
// store `p` inside the new object
```

A source in a Kiosk: `kiosk::borrow_val`, then `derive`, then `kiosk::return_val`, all in one transaction.

Readers check `p.is_verified()`, `p.source_is<T>()` and `p.deriver_package()`, then decide whether to trust that package (for example, by looking it up in the registry).

### Registering

```move
// in your package's init, or later with the Publisher you hold
registry.register(&publisher, b"https://…/manifest.json".to_string(), sha256_of_manifest, ctx);
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
