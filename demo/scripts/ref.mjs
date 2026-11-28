// Record a Walrus content record on Sui testnet as a ContentRef.
//   node ref.mjs publish <recordFile> <blobId>          original (parent stays the record's text reference)
//   node ref.mjs remix <parentObjectId> <recordFile> <blobId>   remix: parent linked with provenance::derive
// Env: CONTENT_PKG (package id), SUI_KEY_FILE (a suiprivkey… secret; testnet throwaway key).
import fs from 'node:fs';
import { SuiGraphQLClient } from '@mysten/sui/graphql';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { Transaction } from '@mysten/sui/transactions';

const PKG = process.env.CONTENT_PKG;
if (!PKG) throw new Error('set CONTENT_PKG');
const kp = Ed25519Keypair.fromSecretKey(fs.readFileSync(process.env.SUI_KEY_FILE, 'utf8').trim());
const client = new SuiGraphQLClient({ url: 'https://graphql.testnet.sui.io/graphql', network: 'testnet' });
const [cmd, ...a] = process.argv.slice(2);
const tx = new Transaction();
tx.setSender(kp.toSuiAddress());
let rec, blob;
if (cmd === 'publish') {
  [rec, blob] = [JSON.parse(fs.readFileSync(a[0], 'utf8')), a[1]];
  tx.moveCall({ target: `${PKG}::content_ref::publish`, arguments: [rec.game, rec.kind, rec.origin.author, rec.name, blob, rec.origin.parent ?? ''].map((s) => tx.pure.string(s)) });
} else if (cmd === 'remix') {
  const parent = a[0];
  [rec, blob] = [JSON.parse(fs.readFileSync(a[1], 'utf8')), a[2]];
  tx.moveCall({
    target: `${PKG}::content_ref::remix`, typeArguments: [`${PKG}::content_ref::ContentRef`],
    arguments: [tx.object(parent), ...[rec.game, rec.kind, rec.origin.author, rec.name, blob].map((s) => tx.pure.string(s))],
  });
} else throw new Error('publish | remix');
const r = await client.signAndExecuteTransaction({ signer: kp, transaction: tx, include: { effects: true, objectTypes: true } });
const t = r.Transaction ?? r.FailedTransaction;
await client.waitForTransaction({ digest: t.digest });
const types = t.objectTypes || {};
const made = (t.effects?.changedObjects || []).find((o) => o.idOperation === 'Created' && (types[o.objectId] || '').endsWith('::content_ref::ContentRef'));
console.log(JSON.stringify({ digest: t.digest, status: t.effects?.status, contentRef: made?.objectId }));
