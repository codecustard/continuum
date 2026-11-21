# The standard (draft v0)

A game is Continuum-compatible if it follows the rules below that apply to it. Everything else is up to each game, so common fields can emerge from use. This draft becomes a one-page spec after two games have shared an object for real.

## 1. Open slots

An object type that wants other games to attach data exposes:

```move
public fun uid_mut(obj: &mut T): &mut UID   // aborts if obj is locked
```

- Other games attach data with `dynamic_field` (or `dynamic_object_field`) on that `UID`.
- **Slot keys are the attaching game's own struct with no public constructor.** Only that game can create the key, so only it can write its slot.
- The owner can lock the object (`locked: bool`) so no new slots can be added.
- `uid_mut` gives access to attached data only. The type's own fields stay private to its module, and deleting the object needs the whole object, not a reference.

## 2. Provenance

An object made from another object stores a `continuum::provenance::Provenance`.

- **Verified:** made by `provenance::derive(witness, &source, ctx)`. The source must be in the same transaction; an owned source needs its owner's signature.
- **Unverified:** made by `provenance::claim(witness, caip19, ctx)`, for sources the chain can't check (other chains, typed-in IDs).
- **The witness is the deriving game's own struct with no public constructor.** Its type names the game in the record.
- A record has no `copy` and no public constructor. It can't be forged or duplicated.

## 3. Registry and manifest

A game registers its package in the shared `continuum::registry::Registry`:

- Keyed by **original package ID**. Registering and editing need the package's `Publisher`.
- Points at a **manifest** (Walrus or GitHub) with its 32-byte hash. Format: [`manifest/schema.json`](../manifest/schema.json).
- The manifest says what the game's fields mean, which types it makes and reads, and the license for its art and data.
- No names on chain. Trust follows the package ID.

## Left out on purpose

- Trust and anti-cheat: each game decides which packages and origins it trusts.
- Balance, stat scales, shared field names.
- Economy of any kind.

## Collections that don't follow the standard

Use a **sidecar**: an object your game owns that holds `derive(&their_object)` (or `claim(caip19)` off-Sui) plus your data. The outside collection never changes.
