// Copyright (c) 0xcodecustard
// SPDX-License-Identifier: MIT

/// Eval fixture: an outside collection that knows nothing about Continuum.
/// No uid_mut, no retire: other games can only read it, derive from it, and keep records about it.
module card::card;

public struct Card has key, store {
    id: UID,
    power: u8,
}

public fun power(card: &Card): u8 { card.power }

#[test_only]
public fun new_for_testing(power: u8, ctx: &mut TxContext): Card {
    Card { id: object::new(ctx), power }
}

#[test_only]
public fun destroy_for_testing(card: Card) {
    let Card { id, .. } = card;
    id.delete();
}
