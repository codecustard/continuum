// Store a file on Walrus testnet through a public publisher (it pays; no keys). Prints the blob id.
// usage: node put-blob.mjs <file> [epochs]
import fs from 'node:fs';
const PUBLISHER = process.env.WALRUS_PUBLISHER || 'https://walrus-testnet-publisher.nodes.guru';
const [file, epochs = '53'] = process.argv.slice(2);
const r = await fetch(`${PUBLISHER}/v1/blobs?epochs=${epochs}`, { method: 'PUT', body: fs.readFileSync(file) });
const j = await r.json();
const id = j.newlyCreated?.blobObject?.blobId ?? j.alreadyCertified?.blobId;
if (!r.ok || !id) { console.error(JSON.stringify(j)); process.exit(1); }
console.log(JSON.stringify({ blobId: id, endEpoch: j.newlyCreated?.blobObject?.storage?.endEpoch ?? j.alreadyCertified?.endEpoch, suiObject: j.newlyCreated?.blobObject?.id }));
