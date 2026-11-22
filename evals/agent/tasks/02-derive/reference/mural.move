module game::mural;

use continuum::provenance::{Self, Provenance};
use koi::koi::Koi;

/// Witness: no public constructor.
public struct Game has drop {}

public struct Mural has key, store {
    id: UID,
    from: Provenance,
}

public fun paint(koi: &Koi, ctx: &mut TxContext): Mural {
    Mural { id: object::new(ctx), from: provenance::derive(Game {}, koi, ctx) }
}

public fun provenance(mural: &Mural): &Provenance { &mural.from }
