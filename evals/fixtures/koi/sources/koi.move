// Copyright (c) 0xcodecustard
// SPDX-License-Identifier: MIT

/// Eval fixture: a minimal Continuum-native type.
/// Follows Rule 1 (uid_mut with an owner lock) and draft Rule 4 (retire by freezing).
module koi::koi;

use std::type_name::{Self, TypeName};
use sui::event;

/// The koi is locked by its owner.
const ELocked: u64 = 0;
/// S-grade koi (grade 4) can't be retired by other games.
const EProtected: u64 = 1;
/// The koi is already retired.
const ERetired: u64 = 2;

public struct Koi has key, store {
    id: UID,
    genes: vector<u8>,
    /// 0 = C ... 4 = S
    grade: u8,
    locked: bool,
    retired: bool,
}

/// Emitted when another game retires a koi.
public struct Retired has copy, drop {
    id: ID,
    by: TypeName,
    into: Option<ID>,
}

// === Rule 1: open slots ===

/// Other games attach their own data here. Aborts if the owner locked the koi.
public fun uid_mut(koi: &mut Koi): &mut UID {
    assert!(!koi.locked, ELocked);
    &mut koi.id
}

/// Read-only access, for reading other games' slots.
public fun uid(koi: &Koi): &UID { &koi.id }

/// Owner switch: stop new slots (and retiring).
public fun lock(koi: &mut Koi) { koi.locked = true }

public fun unlock(koi: &mut Koi) { koi.locked = false }

// === Draft Rule 4: retire ===

/// Take a koi out of play: marked retired, `Retired` event, then frozen (never deleted).
/// The calling game passes its witness and, if it made something from the koi, that object's ID.
public fun retire<W: drop>(_by: W, mut koi: Koi, into: Option<ID>) {
    assert!(!koi.locked, ELocked);
    assert!(!koi.retired, ERetired);
    assert!(koi.grade < 4, EProtected);
    koi.retired = true;
    event::emit(Retired { id: object::id(&koi), by: type_name::with_original_ids<W>(), into });
    transfer::public_freeze_object(koi);
}

// === Reads ===

public fun grade(koi: &Koi): u8 { koi.grade }

public fun genes(koi: &Koi): vector<u8> { koi.genes }

public fun is_locked(koi: &Koi): bool { koi.locked }

public fun is_retired(koi: &Koi): bool { koi.retired }

// === Test helpers ===

#[test_only]
public fun new_for_testing(grade: u8, ctx: &mut TxContext): Koi {
    Koi { id: object::new(ctx), genes: vector[1, 2, 3], grade, locked: false, retired: false }
}

#[test_only]
public fun destroy_for_testing(koi: Koi) {
    let Koi { id, .. } = koi;
    id.delete();
}
