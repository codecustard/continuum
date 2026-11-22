module game::mural;

use continuum::provenance::{Self, Provenance};
use koi::koi::Koi;

public struct Game has drop {}

public struct Mural has key, store { id: UID, from: Provenance }

/// Mistake: claims by CAIP-19 string instead of deriving from the object.
public fun paint(_koi: &Koi, ctx: &mut TxContext): Mural {
    Mural { id: object::new(ctx), from: provenance::claim(Game {}, b"sui:mainnet/koi".to_ascii_string(), ctx) }
}

public fun provenance(mural: &Mural): &Provenance { &mural.from }
