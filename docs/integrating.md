# Integrating a game

## Levels

Each level is optional and they stack.

| Level | You do | You get |
| --- | --- | --- |
| 0. Read | Nothing. Read objects over RPC or the indexer | Use others' assets in your game |
| 1. Register | Claim your `Publisher`, publish a manifest, call `register` | Discoverable; others know your fields and license |
| 2. Derive | Call `derive(YourWitness {}, &their_obj, ctx)` when you make things from others' objects | Verified lineage to the source |
| 3. Open slots | Your types expose `uid_mut` with a lock flag | Other games can attach data to your objects |

## New game

```toml
# Move.toml
[dependencies]
continuum = { git = "https://github.com/codecustard/continuum.git", subdir = "move/continuum", rev = "<commit>" }
```

```move
module tindahan::dish;

use continuum::provenance::{Self, Provenance};

public struct TINDAHAN has drop {}                     // one-time witness → Publisher
public struct Tindahan has drop {}                     // provenance witness, no public constructor
public struct FedSlot has copy, drop, store {}         // slot key, no public constructor

public struct Dish has key, store {
    id: UID,
    from: Provenance,
    locked: bool,
}

/// Rule 1: open slot
public fun uid_mut(d: &mut Dish): &mut UID { assert!(!d.locked); &mut d.id }

/// Rule 2: verified lineage
public fun cook<S: key>(source: &S, ctx: &mut TxContext): Dish {
    Dish { id: object::new(ctx), from: provenance::derive(Tindahan {}, source, ctx), locked: false }
}
```

Rule 3: in `init`, claim the `Publisher` with `package::claim(TINDAHAN {}, ctx)`, then call `registry::register` once with your manifest's URI and hash.

Attaching data to another game's object that has an open slot:

```move
sui::dynamic_field::add(koi.uid_mut(), FedSlot {}, times_fed);
```

## Existing game

- **Already on Sui:** a compatible upgrade can add new public functions. Add `uid_mut` and a lock to your types, claim or reuse your `Publisher`, and register. No migration.
- **Off-chain game:** start at level 0 or 1. Write your results into sidecars.

## Collections that don't know about Continuum

Use a sidecar your game owns:

```move
public struct Record has key { id: UID, of: Provenance, wins: u64 }

// One-time enlist, signed by the holder. In a PTB, take the item out with
// kiosk::borrow_val, call this, then kiosk::return_val.
public fun enlist<T: key>(item: &T, ctx: &mut TxContext) {
    let of = provenance::derive(MyGame {}, item, ctx);
    transfer::share_object(Record { id: object::new(ctx), of, wins: 0 });
}
```

The record is shared and only your package can change it (gate writes with a cap your server holds), so later updates need no player signature. For items on other chains, use `provenance::claim(MyGame {}, caip19, ctx)`; the record is marked unverified.

## Reading provenance

```move
if (p.is_verified() && p.source_is<suikoi::koi::Koi>() && registry.contains(p.deriver_package())) { … }
```

Which derivers to trust is your call; the standard doesn't decide it.
