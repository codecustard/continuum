# Task: keep records about an outside collection

You're building a card-battle game in the Move package in this folder (`game`). Players battle with cards from an outside collection (`card::card::Card`), which knows nothing about Continuum and has no `uid_mut`. The game must keep each card's wins on chain, in a record it controls, linked to the card in a way anyone can verify. Follow Continuum's rules (read `../docs/`).

Write `sources/record.move` with module `game::record` containing:

- `public struct Game has drop {}`: this game's witness.
- `public struct GameCap has key, store { ... }`: held by the game's server; created in `init` and sent to the publisher.
- `#[test_only] public fun init_for_testing(ctx: &mut TxContext)`: runs `init`.
- `public struct CardRecord has key { ... }`
- `public fun enlist(card: &Card, ctx: &mut TxContext)`: creates a `CardRecord` for the card with 0 wins and **shares** it.
- `public fun add_win(cap: &GameCap, record: &mut CardRecord)`: only the game (holder of `GameCap`) can add wins.
- `public fun wins(record: &CardRecord): u64`
- `public fun about(record: &CardRecord): ID`: the card's ID, taken from the verified link.

Add a unit test of your own in `tests/`. Make sure `sui move build` and `sui move test` pass.
