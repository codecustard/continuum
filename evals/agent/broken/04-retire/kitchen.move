module game::kitchen;

use continuum::provenance::{Self, Provenance};
use koi::koi::{Self, Koi};

public struct Kitchen has drop {}
public struct Dish has key, store { id: UID, from: Provenance }

/// Mistake: retires first, then can only claim (unverified) a link.
public fun cook_whole(koi: Koi, ctx: &mut TxContext): Dish {
    koi::retire(Kitchen {}, koi, option::none());
    let from = provenance::claim(Kitchen {}, b"sui:mainnet/koi".to_ascii_string(), ctx);
    Dish { id: object::new(ctx), from }
}

public fun provenance(dish: &Dish): &Provenance { &dish.from }
