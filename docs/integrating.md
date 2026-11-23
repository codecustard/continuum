# Integrating a game

## Levels

Each level is optional and they stack.

| Level | You do | You get |
| --- | --- | --- |
| 0. Read | Nothing. Read objects over RPC or the indexer | Use others' assets in your game |
| 1. Manifest | Publish a manifest; put its link and hash in your package's MVR record | Discoverable; others know your fields and license |
| 2. Derive | Call `derive(YourWitness {}, &their_obj, ctx)` when you make things from others' objects, or keep records about them | Verified lineage to the source |
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

public struct Tindahan has drop {}                     // provenance witness, no public constructor
public struct GuestsCharmed has copy, drop, store {}   // slot key, no public constructor

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

Rule 3: after publishing, create your package's MVR record with your UpgradeCap (`@mvr/metadata::package_info::new`), then `set_metadata` the keys `continuum.manifest` (URI) and `continuum.manifest_hash` (hex hash).

Attaching data to another game's object that has an open slot:

```move
let uid = koi.uid_mut();
if (sui::dynamic_field::exists(uid, GuestsCharmed {})) {
    let n: &mut u64 = sui::dynamic_field::borrow_mut(uid, GuestsCharmed {});
    *n = *n + 1;
} else {
    sui::dynamic_field::add(uid, GuestsCharmed {}, 1u64);   // add aborts if it already exists
};
```

## Existing game

- **Already on Sui:** a compatible upgrade can add new public functions. Add `uid_mut` and a lock to your types, and add your manifest keys to your MVR record. No migration.
- **Off-chain game:** start at level 0 or 1. Write your results into records.

## Collections that don't know about Continuum

Use a record your game owns:

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
if (p.is_verified() && p.source_is<suikoi::koi::Koi>() && p.derived_by<tindahan::dish::Tindahan>()) { … }
```

Which derivers to trust is your call; the standard doesn't decide it.
