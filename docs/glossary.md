# Glossary

Plain-word definitions, in the order you'll meet them.

| Term | Meaning |
| --- | --- |
| **Object** | A thing on Sui with its own ID, like a koi. Usually owned by a wallet; the owner signs to change it. |
| **Type** | What kind of object it is, e.g. `Koi`. Its full name includes its package's address, so a lookalike can't pass as it. |
| **Module** | The code that defines a type. Only it can create the type or touch its fields. |
| **Package** | A published bundle of modules, identified by an address (package ID). |
| **UID** | An object's identity field. Code with `&mut UID` can attach extra data to the object. Private to the type's module unless exposed. |
| **Dynamic field** | Extra named data attached to an object after creation. Built into Sui. |
| **Key** | The name of a dynamic field, usually a small struct. Only the module that defines the key struct can create it. |
| **Slot** | Continuum's word for one game's dynamic field on another game's object. |
| **`uid_mut`** | The public function Rule 1 asks types to expose, so other games can attach slots. Aborts if the owner locked the object. |
| **Lock** | An owner switch on a Continuum object that stops new slots. |
| **Retire** | Continuum's word for taking an object out of play: marked retired, `Retired` event, then frozen. Offered only by the type's own module. |
| **Freeze** | Sui's way to make an object permanent and read-only, owned by nobody (`transfer::public_freeze_object`). |
| **Witness** | A small struct a game defines with no public constructor. Passing it proves "this call comes from that game's code". |
| **Provenance** | A record that an object was made from another one, and by which game. Made by `derive` (verified) or `claim` (unverified). |
| **`derive`** | `continuum::provenance::derive(witness, &source, ctx)`: makes a verified provenance record; the source must be in the same transaction. |
| **`claim`** | Makes an unverified provenance record from a CAIP-19 ID, for sources the chain can't check. |
| **Record** | An object a game owns that points at someone else's object (through `derive` or `claim`) and holds the game's data about it. Used when the object has no slots. |
| **Manifest** | A JSON file describing a game's types, field meanings, slots, witness, license and custody. Linked on chain with its hash. |
| **Content record** | A JSON blob (format `continuum.content/0`) describing something a player made: game, kind, author, what it was remixed from, and the game's own body. Off chain, untrusted until the reader re-checks it. See [content.md](content.md). |
| **Reference** | A string pointing at an item: `kind:id`, `game/kind:id`, `walrus:<blobId>`, `sui:<objectId>` or CAIP-19. A claim until checked. |
| **MVR (Move Registry)** | Sui's registry of package metadata: names, source links, versions. Continuum games add their manifest link there. |
| **UpgradeCap** | The object that controls upgrades of a package. Needed to create its MVR record. |
| **Kiosk** | A personal display case for NFTs on Sui. Supports creator sale rules and listing without giving up the item. |
| **Owner cap (KioskOwnerCap)** | The key to a kiosk. Whoever holds it controls the kiosk and its items. |
| **Transfer policy** | A creator's sale rules for a type held in kiosks, e.g. royalty. Every sale must pass them. |
| **Locked** | An item in a kiosk that can only leave through a sale. |
| **Kiosk extension** | An app the owner installs in a kiosk; it gets its own storage there. |
| **CAIP-19** | A chain-neutral ID format for assets on any chain, e.g. `eip155:1/erc721:0x…/771`. |
| **Transaction (PTB)** | One signed bundle of calls that succeeds or fails as a whole. |
| **zkLogin** | Sui sign-in with a social account; no wallet popups. |
| **Sponsored gas** | The game pays transaction fees, so players don't need SUI. |
