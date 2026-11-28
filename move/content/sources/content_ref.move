// Copyright (c) 0xcodecustard
// SPDX-License-Identifier: MIT

/// ContentRef: one player-made item (a run, a pack, a level) on Sui.
///
/// The item itself is a `continuum.content/0` record stored as a Walrus blob
/// (see docs/content.md). A `ContentRef` points at that blob and says which
/// game it's from, what kind it is and who made it (a pseudonymous handle).
///
/// - `publish` makes an original. Its parent, if any, is only a text
///   reference copied from the record (`week:2026-47`), so it's a claim.
/// - `remix` makes an item from another object, usually another `ContentRef`.
///   It calls Continuum's `provenance::derive`, so the link to the parent is
///   verified on chain: the parent existed, had that type and was passed in.
///
/// ContentRefs are frozen when created: they never change, and because frozen
/// objects can be read by anyone in any transaction, any game can remix them.
///
/// Demo package (testnet only). See docs/demo.md.
module content::content_ref;

use continuum::provenance::{Self, Provenance};
use std::string::String;
use sui::event;

const EBadField: u64 = 0;
const EBadBlob: u64 = 1;

/// The witness this module passes to `derive`. No public constructor.
public struct Content has drop {}

public struct ContentRef has key {
    id: UID,
    /// game that published it, e.g. "every-one-counts"
    game: String,
    /// "run", "pack", ... in that game's terms
    kind: String,
    /// pseudonymous handle (never a raw player id), or a Sui address
    author: String,
    /// display name
    name: String,
    /// Walrus blob id of the continuum.content/0 record
    blob_id: String,
    /// the record's own parent reference (a claim), "" if none
    parent_ref: String,
    /// verified link to the object it was remixed from, if made with `remix`
    parent: Option<Provenance>,
    /// address that signed the publish
    publisher: address,
}

public struct Published has copy, drop {
    id: ID,
    game: String,
    kind: String,
    blob_id: String,
    parent: Option<ID>,
}

/// Publish an original item.
public fun publish(
    game: String,
    kind: String,
    author: String,
    name: String,
    blob_id: String,
    parent_ref: String,
    ctx: &mut TxContext,
): ID {
    make(game, kind, author, name, blob_id, parent_ref, option::none(), ctx)
}

/// Publish an item made from `parent` (another ContentRef, or any object,
/// such as a koi). The link is verified through `provenance::derive`.
public fun remix<S: key>(
    parent: &S,
    game: String,
    kind: String,
    author: String,
    name: String,
    blob_id: String,
    ctx: &mut TxContext,
): ID {
    let p = provenance::derive(Content {}, parent, ctx);
    make(game, kind, author, name, blob_id, b"".to_string(), option::some(p), ctx)
}

fun make(
    game: String,
    kind: String,
    author: String,
    name: String,
    blob_id: String,
    parent_ref: String,
    parent: Option<Provenance>,
    ctx: &mut TxContext,
): ID {
    assert!(slug(&game, 40), EBadField);
    assert!(slug(&kind, 24), EBadField);
    assert!(sized(&author, 66) && sized(&name, 80), EBadField);
    assert!(parent_ref.length() <= 120, EBadField);
    assert!(blob(&blob_id), EBadBlob);
    let parent_id = if (parent.is_some()) parent.borrow().source_id() else option::none();
    let r = ContentRef {
        id: object::new(ctx),
        game, kind, author, name, blob_id, parent_ref, parent,
        publisher: ctx.sender(),
    };
    let id = object::id(&r);
    event::emit(Published { id, game: r.game, kind: r.kind, blob_id: r.blob_id, parent: parent_id });
    transfer::freeze_object(r);
    id
}

// ---- checks ----

fun sized(s: &String, max: u64): bool { let n = s.length(); n > 0 && n <= max }

/// lowercase a-z, 0-9, '-'
fun slug(s: &String, max: u64): bool {
    if (!sized(s, max)) return false;
    let b = s.as_bytes();
    let mut i = 0;
    while (i < b.length()) {
        let c = b[i];
        if (!((c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c == 0x2d)) return false;
        i = i + 1;
    };
    true
}

/// Walrus blob id: 43-44 chars of base64url
fun blob(s: &String): bool {
    let b = s.as_bytes();
    let n = b.length();
    if (n < 43 || n > 44) return false;
    let mut i = 0;
    while (i < n) {
        let c = b[i];
        let ok = (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c == 0x2d || c == 0x5f;
        if (!ok) return false;
        i = i + 1;
    };
    true
}

// ---- reads ----

public fun game(r: &ContentRef): &String { &r.game }
public fun kind(r: &ContentRef): &String { &r.kind }
public fun author(r: &ContentRef): &String { &r.author }
public fun name(r: &ContentRef): &String { &r.name }
public fun blob_id(r: &ContentRef): &String { &r.blob_id }
public fun parent_ref(r: &ContentRef): &String { &r.parent_ref }
public fun parent(r: &ContentRef): &Option<Provenance> { &r.parent }
public fun publisher(r: &ContentRef): address { r.publisher }
