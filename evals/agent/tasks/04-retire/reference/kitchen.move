module game::kitchen;

use continuum::provenance::{Self, Provenance};
use koi::koi::{Self, Koi};

public struct Kitchen has drop {}

public struct Dish has key, store {
    id: UID,
    from: Provenance,
}

public fun cook_whole(koi: Koi, ctx: &mut TxContext): Dish {
    // Prove the link while the koi still exists, then retire it.
    let from = provenance::derive(Kitchen {}, &koi, ctx);
    let dish = Dish { id: object::new(ctx), from };
    koi::retire(Kitchen {}, koi, option::some(object::id(&dish)));
    dish
}

public fun provenance(dish: &Dish): &Provenance { &dish.from }
