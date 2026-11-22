#[test_only]
module game::hidden_kitchen_tests;

use game::kitchen;
use koi::koi::{Self, Koi};
use sui::test_scenario as ts;

#[test]
fun cooks_and_retires_by_freezing() {
    let mut s = ts::begin(@0xA);
    let k = koi::new_for_testing(2, s.ctx());
    let koi_id = object::id(&k);
    let dish = kitchen::cook_whole(k, s.ctx());
    let p = kitchen::provenance(&dish);
    assert!(p.is_verified());
    assert!(p.source_is<Koi>());
    assert!(p.source_id() == option::some(koi_id));
    assert!(p.derived_by<kitchen::Kitchen>());
    transfer::public_transfer(dish, @0xA);
    s.next_tx(@0xA);
    let frozen = s.take_immutable_by_id<Koi>(koi_id);
    assert!(koi::is_retired(&frozen));
    ts::return_immutable(frozen);
    s.end();
}

#[test, expected_failure(abort_code = koi::EProtected)]
fun s_grade_is_protected() {
    let mut s = ts::begin(@0xA);
    let k = koi::new_for_testing(4, s.ctx());
    let dish = kitchen::cook_whole(k, s.ctx());
    transfer::public_transfer(dish, @0xA);
    s.end();
}
