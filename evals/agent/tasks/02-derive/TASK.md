# Task: make something from another game's object (provenance)

You're building a restaurant game in the Move package in this folder (`game`). The game paints a mural of a player's koi (`koi::koi::Koi`) to hang on the wall. Anyone must be able to verify which koi the mural came from and that this game made it, following Continuum's rules (read `../docs/`). The koi is not used up.

Write `sources/mural.move` with module `game::mural` containing:

- `public struct Game has drop {}`: this game's witness.
- `public struct Mural has key, store { ... }`
- `public fun paint(koi: &Koi, ctx: &mut TxContext): Mural`
- `public fun provenance(mural: &Mural): &continuum::provenance::Provenance`

Add a unit test of your own in `tests/`. Make sure `sui move build` and `sui move test` pass.
