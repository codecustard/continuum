# FAQ

Questions people actually asked while designing this. Terms: [glossary.md](glossary.md).

### Isn't composability already part of Sui Move?

Half of it. Sui gives the building blocks: objects that move between packages, public functions anyone can call, dynamic fields for attaching data, keys only their module can create, Kiosk, and transactions that chain many calls. What it doesn't give:

- **Access to another type's `UID`.** An object's fields are private to its module, so other games can't attach data unless the author exposes it. Rule 1 is the convention to expose it.
- **"Made from" proof.** Nothing native records that one object came from another. Rule 2 adds that.
- **Meaning and license.** Types show structure, not what fields mean or how art may be reused. Rule 3 adds that.

Continuum is the thin layer of conventions on top, like ERC-721 on Ethereum.

### So Rule 1 is just making the `UID` public?

Yes. By default a type's `UID` is private to its module. Move lets the author expose it with a public function. Rule 1 asks Continuum types to do that, under the name `uid_mut`, with an owner lock.

### "Only you can create your key": who is "you"?

The **code**: the module that defines the key struct, not a person or wallet. If Gang Wars defines `GangWarsSlot`, only code inside that Gang Wars module can write `GangWarsSlot {}`. Other games can't make it, so they can't write or remove Gang Wars' slots. People can still call Gang Wars' public functions, which create the key internally, so Gang Wars' code decides what gets written.

### Is a slot a predefined placeholder?

No. Nothing is predefined. "Slot" is our word for one piece of extra data attached to an object. A game can attach as many as it likes, each under its own key type (`GangWarsRecordSlot`, `GangWarsBuildingsSlot`, ...), holding any storable value.

### Can anyone add anything to my objects?

Only within limits. With Rule 1, other games can attach **their own** slots to **individual objects**, and only when the object's owner signs. They can't change your fields, your code, or other games' slots, and the owner can lock an object. Without Rule 1, nobody but your module can attach anything.

### What's a record, and why not just use my database?

A record is an object your game owns that points at someone else's object (through `derive`) and holds your data about it, e.g. Gang Wars' wins for One #123. Compared with your own database: other games can read it and trust the link, and it outlives your server. Use records when the object's author didn't adopt Rule 1, which is most existing collections.

### Do collections have to change anything to be used?

No, except for slots. Reading, provenance and records all work on any Sui object as it is. Only slots need the author to expose `uid_mut`.

| Piece | Who opts in |
| --- | --- |
| Slots | The object's author |
| Provenance | The game making the new thing |
| Records | The game |
| Manifest | Each game that wants to be found |

### What is a Kiosk, and does Continuum need it?

A Kiosk is a personal display case for NFTs. It lets a collection's creator enforce sale rules (royalties), and lets owners list items without handing them to a marketplace. Continuum doesn't need or require Kiosk; whether to use it is each collection's choice, outside the standard.

If objects sit in Kiosks, games take them out and put them back within one transaction (`kiosk::borrow_val` and `kiosk::return_val`) to read, derive from, or attach slots to them. The optional `custody` block in the manifest tells builders this up front.

### Are Kiosk extensions an alternative to slots?

They're a third place to keep data. An app installed in a kiosk gets its own storage there and can write it without asking again. The data stays in that kiosk, though, so it doesn't follow an item when it's sold. Slots and records do.

### Kiosk owner vs NFT owner?

Normally the same person: whoever holds the kiosk's owner cap controls the NFTs in it. On chain the NFT's owner is recorded as the kiosk object. They can differ if the cap is transferred, held by a contract, or an app was given limited rights. To find a holder, follow the kiosk to whoever holds its cap.

### Why not just use Sui's Move Registry (MVR) instead of a registry?

Open question. MVR already holds package metadata and accepts custom keys, so the manifest link could live there. Trade-offs: MVR records are owned objects, so a contract can't check "is this package registered?" on chain; creating one needs the package's UpgradeCap; and it depends on MVR rather than our own package. It fits the ecosystem better and handles versions. Nothing is on mainnet, so this can still change.

### Why Sui first?

Objects, dynamic fields, Kiosk, social sign-in (zkLogin) and sponsored gas fit this design best. Reading other chains is planned early: assets stay on their chains, shared game data lives on Sui.

### Do players have to approve a transaction for everything?

No. Only key moments go on chain (minting, breeding, enlisting an NFT), and each is one transaction. With social sign-in and sponsored gas, players see no wallet popups. Records let a game update its data without asking the player again.
