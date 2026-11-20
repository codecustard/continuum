// Copyright (c) 0xcodecustard
// SPDX-License-Identifier: MIT

/// Provenance: a record of where an object came from.
///
/// A game that makes a new object out of an existing one (a dragon from a koi,
/// a battle record from a One) stores a `Provenance` inside the new object.
///
/// - `derive` makes a verified record. It takes a reference to the source
///   object, so the source must be in the same transaction, and an owned
///   source needs its owner's signature. The record stores the source's ID
///   and full type, which names its package.
/// - `claim` makes an unverified record from a CAIP-19 asset ID, for sources
///   the chain can't check (other chains, typed-in IDs).
///
/// Both take a witness `W` from the calling game. `W`'s type names the game
/// that made the record. Rule: a game's witness has no public constructor, so
/// no one else can make records in its name.
///
/// A `Provenance` has no `copy` and no public constructor: it can't be forged
/// or duplicated onto a second object. It can be dropped.
module continuum::provenance;

use std::ascii::String;
use std::type_name::{Self, TypeName};
use sui::address;
use sui::event;

// === Errors ===

/// The witness is a primitive type (u8, vector, ...), which anyone can make.
const EPrimitiveWitness: u64 = 0;
/// The CAIP-19 ID is empty.
const EEmptyCaip19: u64 = 1;
/// The CAIP-19 ID is longer than `MAX_CAIP19_LENGTH`.
const ECaip19TooLong: u64 = 2;

// === Constants ===

/// Longest CAIP-19 ID accepted, in bytes.
const MAX_CAIP19_LENGTH: u64 = 256;

// === Structs ===

/// Where an object came from, and which game recorded it.
public struct Provenance has store, drop {
    source: Source,
    /// Type of the witness of the game that made this record (original package IDs).
    deriver: TypeName,
    /// Sender of the transaction that made this record.
    by: address,
    /// Epoch the record was made in.
    epoch: u64,
}

/// The source object.
public enum Source has store, copy, drop {
    /// A Sui object that was present in the transaction. Verified.
    Sui { id: ID, type_name: TypeName },
    /// A CAIP-19 asset ID the chain can't check. Unverified.
    Claimed { caip19: String },
}

// === Events ===

/// Emitted by `derive`. Indexers build lineage from these.
public struct Derived has copy, drop {
    source_id: ID,
    source_type: TypeName,
    deriver: TypeName,
    by: address,
}

/// Emitted by `claim`.
public struct Claimed has copy, drop {
    caip19: String,
    deriver: TypeName,
    by: address,
}

// === Public functions ===

/// Verified record: `source` is present in this transaction.
///
/// For a source held in a Kiosk, borrow it with `kiosk::borrow_val`, call
/// `derive`, then put it back with `kiosk::return_val` in the same transaction.
public fun derive<S: key, W: drop>(_witness: W, source: &S, ctx: &mut TxContext): Provenance {
    let deriver = witness_type<W>();
    let id = object::id(source);
    let type_name = type_name::with_original_ids<S>();
    event::emit(Derived { source_id: id, source_type: type_name, deriver, by: ctx.sender() });
    Provenance {
        source: Source::Sui { id, type_name },
        deriver,
        by: ctx.sender(),
        epoch: ctx.epoch(),
    }
}

/// Unverified record from a CAIP-19 asset ID,
/// e.g. `eip155:1/erc721:0x06012c8cf97bead5deae237070f9587f8e7a266d/771769`.
/// The format beyond length is not checked on chain.
public fun claim<W: drop>(_witness: W, caip19: String, ctx: &mut TxContext): Provenance {
    assert!(!caip19.is_empty(), EEmptyCaip19);
    assert!(caip19.length() <= MAX_CAIP19_LENGTH, ECaip19TooLong);
    let deriver = witness_type<W>();
    event::emit(Claimed { caip19, deriver, by: ctx.sender() });
    Provenance {
        source: Source::Claimed { caip19 },
        deriver,
        by: ctx.sender(),
        epoch: ctx.epoch(),
    }
}

// === Getters ===

/// True if made by `derive` (source object was present).
public fun is_verified(self: &Provenance): bool {
    match (&self.source) {
        Source::Sui { .. } => true,
        Source::Claimed { .. } => false,
    }
}

public fun source(self: &Provenance): &Source { &self.source }

/// Source object ID, if verified.
public fun source_id(self: &Provenance): Option<ID> {
    match (&self.source) {
        Source::Sui { id, .. } => option::some(*id),
        Source::Claimed { .. } => option::none(),
    }
}

/// Source object type (original package IDs), if verified.
public fun source_type(self: &Provenance): Option<TypeName> {
    match (&self.source) {
        Source::Sui { type_name, .. } => option::some(*type_name),
        Source::Claimed { .. } => option::none(),
    }
}

/// CAIP-19 ID, if claimed.
public fun caip19(self: &Provenance): Option<String> {
    match (&self.source) {
        Source::Sui { .. } => option::none(),
        Source::Claimed { caip19 } => option::some(*caip19),
    }
}

/// True if the source's type is exactly `T`.
public fun source_is<T: key>(self: &Provenance): bool {
    match (&self.source) {
        Source::Sui { type_name, .. } => *type_name == type_name::with_original_ids<T>(),
        Source::Claimed { .. } => false,
    }
}

public fun deriver(self: &Provenance): TypeName { self.deriver }

/// Original package ID of the game that made this record.
/// Look it up in `continuum::registry`.
public fun deriver_package(self: &Provenance): address {
    address::from_ascii_bytes(self.deriver.address_string().as_bytes())
}

/// True if the record was made by the game whose witness is `W`.
public fun derived_by<W>(self: &Provenance): bool {
    self.deriver == type_name::with_original_ids<W>()
}

public fun by(self: &Provenance): address { self.by }

public fun epoch(self: &Provenance): u64 { self.epoch }

// === Internal ===

fun witness_type<W>(): TypeName {
    let t = type_name::with_original_ids<W>();
    assert!(!t.is_primitive(), EPrimitiveWitness);
    t
}
