# Task: use up another game's object (retire)

You're building a restaurant game in the Move package in this folder (`game`). A player can cook their koi (`koi::koi::Koi`) whole into a dish. The koi must be taken out of play the Continuum way, and the dish must keep a verified link to the koi it came from. Read `../docs/` (including the draft retire rule) and the `koi` package's public functions.

Write `sources/kitchen.move` with module `game::kitchen` containing:

- `public struct Kitchen has drop {}`: this game's witness.
- `public struct Dish has key, store { ... }`
- `public fun cook_whole(koi: Koi, ctx: &mut TxContext): Dish`
- `public fun provenance(dish: &Dish): &continuum::provenance::Provenance`

Add a unit test of your own in `tests/`. Make sure `sui move build` and `sui move test` pass.
