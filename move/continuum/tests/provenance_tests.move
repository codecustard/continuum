#[test_only]
module continuum::provenance_tests;

use continuum::provenance;
use std::type_name;

public struct Thing has key { id: UID }
public struct Other has key { id: UID }
public struct Witness has drop {}
public struct OtherWitness has drop {}

fun thing(ctx: &mut TxContext): Thing { Thing { id: object::new(ctx) } }

fun destroy(t: Thing) {
    let Thing { id } = t;
    id.delete();
}

#[test]
fun derive_records_source_and_deriver() {
    let mut ctx = tx_context::dummy();
    let t = thing(&mut ctx);
    let p = provenance::derive(Witness {}, &t, &mut ctx);

    assert!(p.is_verified());
    assert!(p.source_id() == option::some(object::id(&t)));
    assert!(p.source_type() == option::some(type_name::with_original_ids<Thing>()));
    assert!(p.source_is<Thing>());
    assert!(!p.source_is<Other>());
    assert!(p.caip19().is_none());
    assert!(p.derived_by<Witness>());
    assert!(!p.derived_by<OtherWitness>());
    assert!(p.deriver() == type_name::with_original_ids<Witness>());
    assert!(p.deriver_package() == @continuum);
    assert!(p.by() == ctx.sender());
    assert!(p.epoch() == ctx.epoch());

    destroy(t);
}

#[test]
fun claim_is_unverified() {
    let mut ctx = tx_context::dummy();
    let id = b"eip155:1/erc721:0x06012c8cf97bead5deae237070f9587f8e7a266d/771769".to_ascii_string();
    let p = provenance::claim(Witness {}, id, &mut ctx);

    assert!(!p.is_verified());
    assert!(p.caip19() == option::some(id));
    assert!(p.source_id().is_none());
    assert!(p.source_type().is_none());
    assert!(!p.source_is<Thing>());
    assert!(p.derived_by<Witness>());
}

#[test, expected_failure(abort_code = provenance::EEmptyCaip19)]
fun claim_rejects_empty() {
    let mut ctx = tx_context::dummy();
    provenance::claim(Witness {}, b"".to_ascii_string(), &mut ctx);
}

#[test, expected_failure(abort_code = provenance::ECaip19TooLong)]
fun claim_rejects_too_long() {
    let mut ctx = tx_context::dummy();
    let mut bytes = vector[];
    257u64.do!(|_| bytes.push_back(97u8));
    provenance::claim(Witness {}, bytes.to_ascii_string(), &mut ctx);
}

#[test, expected_failure(abort_code = provenance::EPrimitiveWitness)]
fun derive_rejects_primitive_witness() {
    let mut ctx = tx_context::dummy();
    let t = thing(&mut ctx);
    let _p = provenance::derive(0u8, &t, &mut ctx);
    destroy(t);
}

#[test, expected_failure(abort_code = provenance::EPrimitiveWitness)]
fun claim_rejects_vector_witness() {
    let mut ctx = tx_context::dummy();
    provenance::claim(vector<u8>[], b"sui:mainnet/x".to_ascii_string(), &mut ctx);
}
