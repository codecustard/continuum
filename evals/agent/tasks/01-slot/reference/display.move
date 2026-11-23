module game::display;

use koi::koi::Koi;
use sui::dynamic_field as df;

/// Slot key: no public constructor, so only this module can write it.
public struct GuestsCharmed has copy, drop, store {}

public fun charm_guest(koi: &mut Koi) {
    let uid = koi.uid_mut();
    if (df::exists(uid, GuestsCharmed {})) {
        let n: &mut u64 = df::borrow_mut(uid, GuestsCharmed {});
        *n = *n + 1;
    } else {
        df::add(uid, GuestsCharmed {}, 1u64);
    };
}

public fun guests_charmed(koi: &Koi): u64 {
    let uid = koi.uid();
    if (df::exists(uid, GuestsCharmed {})) *df::borrow(uid, GuestsCharmed {}) else 0
}
