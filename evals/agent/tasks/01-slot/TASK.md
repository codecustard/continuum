# Task: keep a count on another game's object (open slot)

You're building a restaurant game in the Move package in this folder (`game`). Players display their koi (from the `koi` package, `koi::koi::Koi`) at their restaurant, and the game keeps a "guests charmed" count **on the koi itself**, following Continuum's rules (read `../docs/`).

Write `sources/display.move` with module `game::display` containing:

- `public fun charm_guest(koi: &mut Koi)`: adds 1 to the koi's guests-charmed count (starting at 1 the first time).
- `public fun guests_charmed(koi: &Koi): u64`: the current count, or 0 if none.

Calling `charm_guest` many times on the same koi must work. Only this game may change its count. Add a unit test of your own in `tests/`. Make sure `sui move build` and `sui move test` pass.
