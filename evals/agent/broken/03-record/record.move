module game::record;

use card::card::Card;
use continuum::provenance::{Self, Provenance};

public struct Game has drop {}
public struct GameCap has key, store { id: UID }
public struct CardRecord has key { id: UID, of: Provenance, wins: u64 }

fun init(ctx: &mut TxContext) { transfer::transfer(GameCap { id: object::new(ctx) }, ctx.sender()) }

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) { init(ctx) }

/// Mistake: gives the record to the player instead of sharing it.
public fun enlist(card: &Card, ctx: &mut TxContext) {
    let of = provenance::derive(Game {}, card, ctx);
    transfer::transfer(CardRecord { id: object::new(ctx), of, wins: 0 }, ctx.sender());
}

public fun add_win(_cap: &GameCap, record: &mut CardRecord) { record.wins = record.wins + 1 }
public fun wins(record: &CardRecord): u64 { record.wins }
public fun about(record: &CardRecord): ID { record.of.source_id().destroy_some() }
