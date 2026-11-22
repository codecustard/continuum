#[test_only]
module game::hidden_mural_tests;

use game::mural;
use koi::koi::{Self, Koi};

#[test]
fun verified_link_to_koi() {
    let mut ctx = tx_context::dummy();
    let k = koi::new_for_testing(3, &mut ctx);
    let m = mural::paint(&k, &mut ctx);
    let p = mural::provenance(&m);
    assert!(p.is_verified());
    assert!(p.source_is<Koi>());
    assert!(p.source_id() == option::some(object::id(&k)));
    assert!(p.derived_by<mural::Game>());
    transfer::public_transfer(m, @0x0);
    koi::destroy_for_testing(k);
}
