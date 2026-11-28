# Content records: `continuum.content/0`

**Status: draft, version 0.** An off-chain format. A demo package records these on Sui testnet as `ContentRef` objects (see [On chain](#on-chain-contentref-demo-testnet)).

A content record is a small JSON document describing something a player made in a game: a level, a run, a pack of cards, a recipe. It's stored as one blob (today on Walrus testnet), so any game can load it by its blob ID, see who made it and what it was remixed from, and decide for itself whether to play it.

The shared part is the **envelope** (what it is, which game, who made it, what it came from). The content itself, the **body**, is each game's own format.

First user: Every One Counts publishes player-made runs and packs this way.

## Example

```json
{
  "schema": "continuum.content/0",
  "game": "every-one-counts",
  "kind": "run",
  "id": "w-ab12cd34",
  "name": "Pinata Rush",
  "origin": {
    "author": "p-7f3a91",
    "parent": "week:2026-47",
    "game": "every-one-counts"
  },
  "body": {
    "pack": "custards",
    "blurb": "Every hit drops candy.",
    "file": { "...": "the game's own run format" }
  },
  "assets": {
    "/api/asset?id=u-5c2e": "Xb3kq0vRz8yT1mN4pL6wJ2dF9sA7cH5gE0uI3oK8rB"
  },
  "published": "2026-11-26T12:00:00Z"
}
```

## Envelope

| Field | Required | Meaning |
| --- | --- | --- |
| `schema` | yes | Exactly `continuum.content/0`. Readers check this first. |
| `game` | yes | Slug of the game that **published** this record (lowercase, `a-z0-9-`). |
| `kind` | yes | What it is, in the publishing game's terms (`run`, `pack`, `level`). Game-defined. |
| `id` | yes | The item's ID inside that game. Unique per `game` + `kind`. |
| `name` | yes | Display name. Plain text; readers escape it. |
| `origin` | yes | Who made it and what it came from (below). |
| `body` | yes | The content, in the game's own format (below). |
| `assets` | no | Files the body refers to: path used in `body` → blob ID. |
| `published` | yes | When it was published, RFC 3339 in UTC. Set by the publisher, so not proof of anything. |

Unknown top-level fields are allowed and ignored by readers that don't know them.

## `origin`

Same shape as Every One Counts' `origin` (`shared/origin.ts`):

| Field | Meaning |
| --- | --- |
| `author` | Who made it: a **pseudonymous handle** (Every One Counts uses `p-` + 12 hex, derived from the player ID with a server secret), the studio's name, or a Sui address **only if the player signed with that wallet**. Never a raw player or guest ID: records are public and permanent. Not verified. |
| `parent` | What it was remixed or built from, as a reference (below), or `null` for an original. |
| `game` | The game where it was **made**. Usually the same as the envelope's `game`; differs when one game republishes another game's content. |

### References (`parent`)

One string, in one of these forms:

| Form | Points at | Example |
| --- | --- | --- |
| `kind:id` | Another item in `origin.game` | `week:2026-47`, `pack:p-19` |
| `game/kind:id` | An item in another game, by its ID there | `suikoi/week:dragon-gate` |
| `walrus:<blobId>` | Another published content record | `walrus:Xb3kq0vR…` |
| `sui:<objectId>` | An object on Sui (for example a koi) | `sui:0x5a1c…` |
| CAIP-19 | An item on another chain | `eip155:1/erc721:0x…/42` |

The first form is what Every One Counts writes today. For anything that crosses games, prefer `walrus:` (another record) or `sui:` (an on-chain object): those can be fetched without knowing the other game's internals. `game/kind:id` only names the item; the reader has to know how to find it.

A reference is a claim by the author or publisher. The parent may not exist, may be unreachable, or may say something different. Readers show it as "says it's a remix of …", and only treat it as fact when they can check it.

## `body`

Game-defined. Continuum doesn't constrain it beyond being JSON. A game should describe its `body` shape for each `kind` in its manifest (Rule 3) once content is declared there; until then, in its own docs.

A reader that doesn't know the game shows the envelope (name, game, author, parent) and leaves `body` alone. Games version their own body (for example a `v` field inside it); that's separate from the envelope version.

## `assets`

Maps each file path the body uses to the blob ID of that file. A reader fetches assets from a Walrus aggregator it chooses. Assets are as untrusted as the record: Every One Counts shows images only when it published them itself and uses stand-ins otherwise. Other games can choose their own rule.

## Reading a record

A record is **untrusted input**. Anyone can store a blob that claims any `game`, `author` or `parent`. A reader must:

1. Cap the size before parsing (Every One Counts uses 120 KB).
2. Check `schema` is a version it knows; reject anything else.
3. Re-check `body` against its own rules (limits, stat budgets, allowed values) as if a stranger typed it in. Never trust that the publishing game already checked it.
4. Treat `author`, `origin` and `published` as labels, not proof.
5. Escape `name` and any text in `body` before showing it.
6. Rate-limit loads by blob ID if loading is public.

What the blob ID does guarantee: the content is exactly what was stored (Walrus IDs are derived from the content). It says nothing about who stored it.

## Versioning

- `/0` is a draft. While on `/0`, only **new optional fields** may be added; readers ignore fields they don't know.
- Removing or renaming a field, making an optional field required, or changing what a field means requires `/1`.
- Readers accept only versions they know. A game that reads `/1` should keep reading `/0` for records already stored.
- Body changes are the game's own business and never bump the envelope version.

## On chain: `ContentRef` (demo, testnet)

The `content` package (`move/content`) records a content record on Sui:

- `publish(game, kind, author, name, blob_id, parent_ref)` makes an original. Its `parent_ref` is the record's own text reference, so it stays a claim.
- `remix<S: key>(parent: &S, game, kind, author, name, blob_id)` makes an item from another object, usually another `ContentRef`. It calls `provenance::derive`, so the parent link is **verified**.
- A `ContentRef` is frozen when created: it never changes, and any game can read it or remix from it in any transaction.

A remix's own record should name the same parent as `sui:<ContentRef id>`. Package IDs and a walkthrough: [demo.md](demo.md).

## Later (not built)

Today the record lives only on Walrus. The planned link to Continuum's rules, once players actually make content:

- **Ownership.** Each Walrus store creates a Sui `Blob` object. Holding it in the game's address makes every published item a Sui object the game controls.
- **Each game's own witness.** The demo's `ContentRef` uses one witness for every game, so `derived_by` says "the content module", not which game. A production version would let each game derive with its own witness.
- **Parents that can't be passed in** (another chain, an off-chain item) would use `provenance::claim` and stay unverified, exactly as Rule 2 says today.
- **Manifest (Rule 3).** A game's manifest would declare the content it publishes (kinds, body shapes, the aggregator it uses), so indexers can list it.

Until then, `walrus:` and `sui:` references are the bridge: the same strings can later be checked on chain.
