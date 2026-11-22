#[test_only]
module game::hidden_display_tests;

use game::display;
use koi::koi;

#[test]
fun counts_up() {
    let mut ctx = tx_context::dummy();
    let mut k = koi::new_for_testing(2, &mut ctx);
    assert!(display::guests_charmed(&k) == 0);
    display::charm_guest(&mut k);
    display::charm_guest(&mut k);
    display::charm_guest(&mut k);
    assert!(display::guests_charmed(&k) == 3);
    koi::destroy_for_testing(k);
}

#[test, expected_failure(abort_code = koi::ELocked)]
fun respects_lock() {
    let mut ctx = tx_context::dummy();
    let mut k = koi::new_for_testing(2, &mut ctx);
    k.lock();
    display::charm_guest(&mut k);
    koi::destroy_for_testing(k);
}
