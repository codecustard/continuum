module game::display;

use koi::koi::Koi;
use sui::dynamic_field as df;

public struct GuestsCharmed has copy, drop, store {}

public fun charm_guest(koi: &mut Koi) {
    df::add(koi.uid_mut(), GuestsCharmed {}, 1u64);
}

public fun guests_charmed(koi: &Koi): u64 {
    if (df::exists_(koi.uid(), GuestsCharmed {})) *df::borrow(koi.uid(), GuestsCharmed {}) else 0
}
