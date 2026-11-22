#[test_only]
module game::hidden_record_tests;

use card::card;
use game::record::{Self, CardRecord, GameCap};
use sui::test_scenario as ts;

#[test]
fun record_links_to_card_and_counts_wins() {
    let mut s = ts::begin(@0xA);
    record::init_for_testing(s.ctx());
    s.next_tx(@0xB);
    let c = card::new_for_testing(7, s.ctx());
    record::enlist(&c, s.ctx());
    s.next_tx(@0xA);
    let mut rec = s.take_shared<CardRecord>();
    let cap = s.take_from_sender<GameCap>();
    assert!(record::about(&rec) == object::id(&c));
    assert!(record::wins(&rec) == 0);
    record::add_win(&cap, &mut rec);
    assert!(record::wins(&rec) == 1);
    ts::return_shared(rec);
    s.return_to_sender(cap);
    card::destroy_for_testing(c);
    s.end();
}
