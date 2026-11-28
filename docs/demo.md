# Demo: one item, two games (Sui testnet)

A run made in **Every One Counts** is stored on Walrus, recorded on Sui as a `ContentRef`, then read, drawn and remixed by a second game. Each remix's link to its parent is made with Continuum's `provenance::derive`, so the lineage is verified on chain.

**Live page:** https://codecustard.github.io/continuum/demo/

## What's on testnet

| What | ID |
| --- | --- |
| `continuum` package (provenance) | `0xc2d92a3cea069c9f967f9c913991f2565bf5b073b581c5178f9dba12302796e8` |
| `content` package (`ContentRef`) | `0xceadf57865927408659b8e0acb543bda5f754e10a5a271c63b15af6a82641aa3` |
| Original: *Block Party* (Every One Counts) | ContentRef `0x47e8725c9a53b2917922c3db5bfac3dfd6743e0889a54fb8c84f73bf2878e1c4`, record blob `f0vP2hOST23DjxJ0yCv77GqFIC7jkeQOOyBSXVgXxPY` |
| Remix: *Block Party, Goose Rush* (demo game) | ContentRef `0x8f274fcb5a5d79d2c88c381031fb481cf3cc978ab0667574fbbc01a6c01ee515`, record blob `n49uDq3gLVwA-Kheij1H5cr8WCokNf_r-XMIVNM3XCA` |
| Remix of the remix: *…, Speedrun* (made from the page with a wallet) | ContentRef `0xe96a136211ad81d8e19bab1858e763eda87ef564a67553128bc4d57660a01e80` |

Explorer: `https://suiscan.xyz/testnet/object/<id>`. Records: `https://aggregator.walrus-testnet.walrus.space/v1/blobs/<blob id>`. Walrus testnet keeps the blobs for 53 epochs (about 53 days, to mid-January 2027); store them again before then if the demo must stay up.

The `content` package is separate from `continuum` on purpose: it's a demo of the content format, not part of the standard, and adding it to `continuum` would need an upgrade signed with the maintainer's wallet. It links to the published `continuum` package (`move/continuum/Published.toml`). Its UpgradeCap is held by the throwaway deploy key.

## How it works

1. **Made in game A.** *Block Party* is a studio run from Every One Counts (`weeks/block-party.json`), written as a `continuum.content/0` record ([content.md](content.md)) and stored on Walrus. Every One Counts can load it back: `https://ones.suikoi.life/?walrus=<blob id>` (that makes a local copy on the server).
2. **Recorded on Sui.** `content_ref::publish` makes a `ContentRef` (game, kind, author handle, name, blob ID) and freezes it, so any game can read it in any transaction.
3. **Read in game B.** The demo page reads the `ContentRef` from Sui GraphQL, fetches the record from the Walrus aggregator, checks it (schema, size cap, escaped text) and draws the waves its own way.
4. **Remixed in game B.** "Remix it here" changes the run, stores the new record on Walrus, then asks the wallet to sign `content_ref::remix(parent, …)`. That calls `provenance::derive` with the parent object, so the new `ContentRef` carries a verified link to it.
5. **Lineage.** The page walks parent links on chain back to the original and marks each one "verified by `provenance::derive`".

## Run it yourself

- **Read:** open the live page, or paste any ContentRef ID.
- **Remix:** install a Sui wallet (Slush), switch it to **testnet**, get testnet SUI (faucet), open the page, pick a remix. The page stores the record through a public Walrus testnet publisher (it pays the storage).
- **From scripts** (`demo/`):
  ```sh
  cd demo && npm install
  node scripts/put-blob.mjs records/block-party.json 53          # -> blob id
  CONTENT_PKG=0xcead…1aa3 SUI_KEY_FILE=key.txt node scripts/ref.mjs publish records/block-party.json <blob id>
  CONTENT_PKG=0xcead…1aa3 SUI_KEY_FILE=key.txt node scripts/ref.mjs remix <parent ContentRef> records/goose-rush.json <blob id>
  ```
  `key.txt` holds a testnet-only `suiprivkey…` secret.
- **Rebuild the page:** `cd demo && npm run build` (writes `site/demo/app.js`). IDs live in `site/demo/config.js`.
- **Move tests:** `cd move/content && sui move test` (4 tests).

## Limits (on purpose, for a demo)

- Testnet only; records and refs are public and permanent.
- One witness for every game: `derived_by` says "the content module", not which game. Production would give each game its own witness.
- `game`, `author` and the record's text are what the publisher wrote; only the parent link and the blob's content are verified.
- The original is a studio run, not a player's. Player content replaces it after the Every One Counts Reddit test.

## 60-second clip (script)

Screen recording at 1280×720, browser zoom 110%, cursor visible. No voice needed; captions in brackets.

| Time | On screen | Caption |
| --- | --- | --- |
| 0:00–0:08 | Every One Counts, playing *Block Party* (the duck wave) | [A run made in Every One Counts] |
| 0:08–0:15 | Suiscan: the original ContentRef `0x47e8…e1c4`, fields visible (game, author, blob_id) | [Recorded on Sui as a ContentRef. The run itself lives on Walrus] |
| 0:15–0:25 | Demo page loads the original: "made in Every One Counts by 0xccgg", waves drawn | [A second game reads it from Sui and draws it its own way] |
| 0:25–0:40 | Click "Speedrun", wallet (Slush, testnet) pops up, approve; page reloads with the new item | [Remix it. The wallet signs one transaction] |
| 0:40–0:52 | Lineage section: new item → Goose Rush → Block Party, each "verified by provenance::derive" | [Lineage is verified on chain, not claimed] |
| 0:52–0:60 | Repo and site URL | [Continuum: open standard for games that build on each other. github.com/codecustard/continuum] |

Before recording: have testnet SUI in the wallet, and remix from *Goose Rush* so the chain shows three items.
