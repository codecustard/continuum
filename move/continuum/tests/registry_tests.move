#[test_only]
module continuum::registry_tests;

use continuum::provenance;
use continuum::registry::{Self, Registry};
use std::type_name;
use sui::package::{Self, Publisher};
use sui::test_scenario::{Self as ts, Scenario};

const ADMIN: address = @0xA;
const GAME_DEV: address = @0xB;

/// Stands in for a game's one-time witness.
public struct GAME has drop {}
public struct Witness has drop {}
public struct Thing has key { id: UID }

const URI: vector<u8> = b"https://github.com/codecustard/suikoi/continuum.json";

fun hash(): vector<u8> {
    let mut h = vector[];
    32u64.do!(|i| h.push_back(i as u8));
    h
}

fun setup(): Scenario {
    let mut s = ts::begin(ADMIN);
    registry::init_for_testing(s.ctx());
    s.next_tx(GAME_DEV);
    s
}

/// Publisher for this test package (@continuum).
fun our_publisher(s: &mut Scenario): Publisher { package::test_claim(GAME {}, s.ctx()) }

/// Publisher for another package (0x1).
fun other_publisher(s: &mut Scenario): Publisher {
    package::test_claim(std::ascii::char(65), s.ctx())
}

fun finish(s: Scenario, reg: Registry, publisher: Publisher) {
    ts::return_shared(reg);
    package::burn_publisher(publisher);
    s.end();
}

#[test]
fun register_and_read() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);

    assert!(!reg.contains(@continuum));
    reg.register(&publisher, URI.to_string(), hash(), s.ctx());

    assert!(reg.contains(@continuum));
    assert!(reg.length() == 1);
    let entry = reg.borrow(@continuum);
    assert!(entry.publisher() == object::id(&publisher));
    assert!(entry.latest() == @continuum);
    assert!(entry.manifest().uri() == URI.to_string());
    assert!(entry.manifest().hash() == hash());
    assert!(!reg.contains(@0x1));

    finish(s, reg, publisher);
}

#[test]
fun update_manifest_and_latest() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);
    reg.register(&publisher, URI.to_string(), hash(), s.ctx());

    let mut h2 = hash();
    h2.reverse();
    reg.update_manifest(&publisher, b"walrus://blob123".to_string(), h2, s.ctx());
    reg.set_latest(&publisher, @0xBEEF, s.ctx());

    let entry = reg.borrow(@continuum);
    assert!(entry.manifest().uri() == b"walrus://blob123".to_string());
    assert!(entry.manifest().hash() == h2);
    assert!(entry.latest() == @0xBEEF);

    finish(s, reg, publisher);
}

#[test]
fun deriver_lookup_matches_registry() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);
    reg.register(&publisher, URI.to_string(), hash(), s.ctx());

    let thing = Thing { id: object::new(s.ctx()) };
    let p = provenance::derive(Witness {}, &thing, s.ctx());
    assert!(reg.contains(p.deriver_package()));
    assert!(reg.contains_type_name(&p.deriver()));
    assert!(!reg.contains_type_name(&type_name::with_original_ids<std::ascii::Char>()));

    let Thing { id } = thing;
    id.delete();
    finish(s, reg, publisher);
}

#[test]
fun two_packages_get_separate_entries() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let ours = our_publisher(&mut s);
    let theirs = other_publisher(&mut s);
    reg.register(&ours, URI.to_string(), hash(), s.ctx());
    reg.register(&theirs, b"https://example.com/m.json".to_string(), hash(), s.ctx());

    assert!(reg.length() == 2);
    assert!(reg.borrow(@0x1).publisher() == object::id(&theirs));
    assert!(reg.borrow(@continuum).publisher() == object::id(&ours));

    package::burn_publisher(theirs);
    finish(s, reg, ours);
}

#[test, expected_failure(abort_code = registry::EAlreadyRegistered)]
fun register_twice_fails() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);
    reg.register(&publisher, URI.to_string(), hash(), s.ctx());
    reg.register(&publisher, URI.to_string(), hash(), s.ctx());
    finish(s, reg, publisher);
}

#[test, expected_failure(abort_code = registry::ENotRegistered)]
fun other_package_cannot_update() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let ours = our_publisher(&mut s);
    reg.register(&ours, URI.to_string(), hash(), s.ctx());

    // A publisher from a different package edits its own (missing) entry, never ours.
    let theirs = other_publisher(&mut s);
    reg.update_manifest(&theirs, b"evil".to_string(), hash(), s.ctx());

    package::burn_publisher(theirs);
    finish(s, reg, ours);
}

#[test, expected_failure(abort_code = registry::ENotRegistered)]
fun set_latest_unregistered_fails() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);
    reg.set_latest(&publisher, @0xBEEF, s.ctx());
    finish(s, reg, publisher);
}

#[test, expected_failure(abort_code = registry::EBadHash)]
fun bad_hash_fails() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);
    reg.register(&publisher, URI.to_string(), b"short", s.ctx());
    finish(s, reg, publisher);
}

#[test, expected_failure(abort_code = registry::EEmptyUri)]
fun empty_uri_fails() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);
    reg.register(&publisher, b"".to_string(), hash(), s.ctx());
    finish(s, reg, publisher);
}

#[test, expected_failure(abort_code = registry::EUriTooLong)]
fun long_uri_fails() {
    let mut s = setup();
    let mut reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);
    let mut bytes = vector[];
    513u64.do!(|_| bytes.push_back(97u8));
    reg.register(&publisher, bytes.to_string(), hash(), s.ctx());
    finish(s, reg, publisher);
}

#[test, expected_failure(abort_code = registry::ENotRegistered)]
fun borrow_missing_fails() {
    let mut s = setup();
    let reg = s.take_shared<Registry>();
    let publisher = our_publisher(&mut s);
    reg.borrow(@continuum);
    finish(s, reg, publisher);
}
