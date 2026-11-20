// Copyright (c) 0xcodecustard
// SPDX-License-Identifier: MIT

/// Registry: the on-chain list of games that joined Continuum.
///
/// One shared `Registry`. Each entry is keyed by a game's original package ID
/// and points at its manifest (Walrus or GitHub) with the manifest's hash.
///
/// - Anyone can register, but only their own package: registering and editing
///   need a `Publisher` from that package.
/// - No names on chain. The name lives in the manifest; trust follows the
///   package ID.
/// - No approval, curation, fees or removal. Who to trust is each game's call.
module continuum::registry;

use std::string::String;
use std::type_name::TypeName;
use sui::address;
use sui::event;
use sui::package::Publisher;
use sui::table::{Self, Table};

// === Errors ===

/// The package already has an entry.
const EAlreadyRegistered: u64 = 0;
/// The package has no entry.
const ENotRegistered: u64 = 1;
/// The manifest URI is empty.
const EEmptyUri: u64 = 2;
/// The manifest URI is longer than `MAX_URI_LENGTH`.
const EUriTooLong: u64 = 3;
/// The manifest hash is not 32 bytes.
const EBadHash: u64 = 4;

// === Constants ===

/// Longest manifest URI accepted, in bytes.
const MAX_URI_LENGTH: u64 = 512;
/// Manifest hash length: SHA-256 or Blake2b-256.
const HASH_LENGTH: u64 = 32;

// === Structs ===

/// The shared registry. Created once at publish.
public struct Registry has key {
    id: UID,
    entries: Table<address, Entry>,
}

/// One game's entry.
public struct Entry has store {
    /// The `Publisher` that registered it.
    publisher: ID,
    /// Current package ID after upgrades, as set by the publisher.
    /// Starts as the original package ID.
    latest: address,
    manifest: Manifest,
    registered_epoch: u64,
    updated_epoch: u64,
}

/// Where the manifest lives and its 32-byte hash.
public struct Manifest has store, copy, drop {
    uri: String,
    hash: vector<u8>,
}

// === Events ===

public struct Registered has copy, drop {
    package: address,
    publisher: ID,
    manifest: Manifest,
}

public struct ManifestUpdated has copy, drop {
    package: address,
    manifest: Manifest,
}

public struct LatestSet has copy, drop {
    package: address,
    latest: address,
}

// === Init ===

fun init(ctx: &mut TxContext) {
    transfer::share_object(Registry { id: object::new(ctx), entries: table::new(ctx) });
}

// === Publisher functions ===

/// Register the package `publisher` belongs to.
public fun register(
    self: &mut Registry,
    publisher: &Publisher,
    uri: String,
    hash: vector<u8>,
    ctx: &mut TxContext,
) {
    let package = package_of(publisher);
    assert!(!self.entries.contains(package), EAlreadyRegistered);
    let manifest = new_manifest(uri, hash);
    self
        .entries
        .add(
            package,
            Entry {
                publisher: object::id(publisher),
                latest: package,
                manifest,
                registered_epoch: ctx.epoch(),
                updated_epoch: ctx.epoch(),
            },
        );
    event::emit(Registered { package, publisher: object::id(publisher), manifest });
}

/// Point the entry at a new manifest.
public fun update_manifest(
    self: &mut Registry,
    publisher: &Publisher,
    uri: String,
    hash: vector<u8>,
    ctx: &mut TxContext,
) {
    let package = package_of(publisher);
    assert!(self.entries.contains(package), ENotRegistered);
    let manifest = new_manifest(uri, hash);
    let entry = &mut self.entries[package];
    entry.manifest = manifest;
    entry.updated_epoch = ctx.epoch();
    event::emit(ManifestUpdated { package, manifest });
}

/// Record the package's current ID after an upgrade. Not checked on chain:
/// it is the publisher's statement.
public fun set_latest(self: &mut Registry, publisher: &Publisher, latest: address, ctx: &mut TxContext) {
    let package = package_of(publisher);
    assert!(self.entries.contains(package), ENotRegistered);
    let entry = &mut self.entries[package];
    entry.latest = latest;
    entry.updated_epoch = ctx.epoch();
    event::emit(LatestSet { package, latest });
}

// === Reads ===

/// True if `package` (an original package ID) is registered.
public fun contains(self: &Registry, package: address): bool {
    self.entries.contains(package)
}

/// True if the package that defines `type_name` is registered.
/// Pass a `TypeName` made with original IDs, such as `provenance::deriver`.
public fun contains_type_name(self: &Registry, type_name: &TypeName): bool {
    self.entries.contains(address::from_ascii_bytes(type_name.address_string().as_bytes()))
}

/// Entry for `package`. Aborts if not registered.
public fun borrow(self: &Registry, package: address): &Entry {
    assert!(self.entries.contains(package), ENotRegistered);
    &self.entries[package]
}

public fun length(self: &Registry): u64 { self.entries.length() }

public fun publisher(entry: &Entry): ID { entry.publisher }

public fun latest(entry: &Entry): address { entry.latest }

public fun manifest(entry: &Entry): Manifest { entry.manifest }

public fun registered_epoch(entry: &Entry): u64 { entry.registered_epoch }

public fun updated_epoch(entry: &Entry): u64 { entry.updated_epoch }

public fun uri(manifest: &Manifest): String { manifest.uri }

public fun hash(manifest: &Manifest): vector<u8> { manifest.hash }

// === Internal ===

/// Original package ID of the package `publisher` belongs to.
fun package_of(publisher: &Publisher): address {
    address::from_ascii_bytes(publisher.published_package().as_bytes())
}

fun new_manifest(uri: String, hash: vector<u8>): Manifest {
    assert!(!uri.is_empty(), EEmptyUri);
    assert!(uri.length() <= MAX_URI_LENGTH, EUriTooLong);
    assert!(hash.length() == HASH_LENGTH, EBadHash);
    Manifest { uri, hash }
}

// === Test only ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
