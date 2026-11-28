#[test_only]
module content::content_ref_tests;

use content::content_ref::{Self, ContentRef, Content};
use sui::test_scenario as ts;

const BLOB_A: vector<u8> = b"Xb3kq0vRz8yT1mN4pL6wJ2dF9sA7cH5gE0uI3oK8rBQ";
const BLOB_B: vector<u8> = b"Yc4lr1wSa9zU2nO5qM7xK3eG0tB8dI6hF1vJ4pL9sCR";

public struct Koi has key { id: UID }

#[test]
fun publish_then_remix_has_verified_lineage() {
    let mut s = ts::begin(@0xA);
    let a = content_ref::publish(b"every-one-counts".to_string(), b"run".to_string(), b"0xccgg".to_string(), b"Block Party".to_string(), BLOB_A.to_string(), b"".to_string(), s.ctx());
    s.next_tx(@0xB);
    let orig = s.take_immutable_by_id<ContentRef>(a);
    assert!(orig.parent().is_none());
    assert!(*orig.game() == b"every-one-counts".to_string());
    let b = content_ref::remix(&orig, b"continuum-demo".to_string(), b"run".to_string(), b"p-1a2b3c4d5e6f".to_string(), b"Block Party, Goose Rush".to_string(), BLOB_B.to_string(), s.ctx());
    ts::return_immutable(orig);
    s.next_tx(@0xB);
    let rmx = s.take_immutable_by_id<ContentRef>(b);
    let p = rmx.parent().borrow();
    assert!(p.is_verified());
    assert!(p.source_id() == option::some(a));
    assert!(p.source_is<ContentRef>());
    assert!(p.derived_by<Content>());
    assert!(rmx.publisher() == @0xB);
    ts::return_immutable(rmx);
    s.end();
}

#[test]
fun remix_from_any_object() {
    let mut s = ts::begin(@0xA);
    let k = Koi { id: object::new(s.ctx()) };
    let kid = object::id(&k);
    let b = content_ref::remix(&k, b"suikoi".to_string(), b"portrait".to_string(), b"0xccgg".to_string(), b"Benibana".to_string(), BLOB_B.to_string(), s.ctx());
    transfer::transfer(k, @0xA);
    s.next_tx(@0xA);
    let r = s.take_immutable_by_id<ContentRef>(b);
    assert!(r.parent().borrow().source_is<Koi>());
    assert!(r.parent().borrow().source_id() == option::some(kid));
    ts::return_immutable(r);
    s.end();
}

#[test, expected_failure(abort_code = content_ref::EBadBlob)]
fun rejects_bad_blob_id() {
    let mut s = ts::begin(@0xA);
    content_ref::publish(b"every-one-counts".to_string(), b"run".to_string(), b"0xccgg".to_string(), b"x".to_string(), b"not-a-blob".to_string(), b"".to_string(), s.ctx());
    s.end();
}

#[test, expected_failure(abort_code = content_ref::EBadField)]
fun rejects_bad_game_slug() {
    let mut s = ts::begin(@0xA);
    content_ref::publish(b"Every One Counts".to_string(), b"run".to_string(), b"0xccgg".to_string(), b"x".to_string(), BLOB_A.to_string(), b"".to_string(), s.ctx());
    s.end();
}
