#!/usr/bin/env node
// Seeds Firestore with the game's starting data (spec «Данные», APP-13):
//   config/game, districts/{id}, questPlaces/{placeId}, questCodes/{placeId}.
// Quest codes are also written to tools/qr/codes.json (gitignored) for the
// QR generator (APP-15). Existing codes there are reused, so re-running the
// seed does not invalidate printed QR codes; pass --new-codes to rotate them.
//
// Emulator (default; FIRESTORE_EMULATOR_HOST or localhost:8080):
//   node tools/firestore-seed/seed.mjs [--project coollodz]
// Real project (Firestore REST API, OAuth token from `gcloud auth print-access-token`):
//   node tools/firestore-seed/seed.mjs --project coollodz --token "$(gcloud auth print-access-token)"
//
// Options:
//   --project <id>     project id (default: coollodz, the id the debug app uses)
//   --token <oauth>    write to the real project instead of the emulator
//   --quest <file>     default assets/demo/quest.json
//   --places <file>    default assets/demo/places_cool.json
//   --codes <file>     default tools/qr/codes.json
//   --new-codes        generate new codes for every place
//   --force            also overwrite config/game and districts (resets points!)
//   --dry-run          print what would be written, write nothing
import { randomInt } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');

// Must match FirestoreDistricts in lib/core/firestore/collections.dart and
// districtIds() in firestore.rules.
const DISTRICTS = {
  baluty: 'Bałuty',
  gorna: 'Górna',
  polesie: 'Polesie',
  srodmiescie: 'Śródmieście',
  widzew: 'Widzew',
};
const DEFAULT_QUEST_ID = 'chlodne-haslo-2026';
// No 0/O and 1/I/L, so a code read off a printed sheet is unambiguous.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;

function fail(message) {
  console.error(`seed: ${message}`);
  process.exit(1);
}

const { values: opts } = parseArgs({
  options: {
    project: { type: 'string', default: 'coollodz' },
    token: { type: 'string' },
    quest: { type: 'string', default: 'assets/demo/quest.json' },
    places: { type: 'string', default: 'assets/demo/places_cool.json' },
    codes: { type: 'string', default: 'tools/qr/codes.json' },
    'new-codes': { type: 'boolean', default: false },
    force: { type: 'boolean', default: false },
    'dry-run': { type: 'boolean', default: false },
  },
});

function readJson(path, what) {
  const file = resolve(repoRoot, path);
  if (!existsSync(file)) {
    fail(`${what} not found: ${file}\n` +
      '  The quest data comes from APP-05 (assets/demo/quest.json, assets/demo/places_cool.json).\n' +
      '  Merge it first or pass --quest / --places.');
  }
  try {
    return JSON.parse(readFileSync(file, 'utf8'));
  } catch (e) {
    fail(`${what} is not valid JSON (${file}): ${e.message}`);
  }
}

// ---- build the documents ----------------------------------------------------

const quest = readJson(opts.quest, 'Quest file');
const placesFile = readJson(opts.places, 'Places file');
const places = new Map((placesFile.places ?? placesFile).map((p) => [p.id, p]));
if (!Array.isArray(quest.places) || quest.places.length === 0) {
  fail(`${opts.quest}: expected a non-empty "places" array`);
}

const questPlaces = quest.places.map((q) => {
  const place = places.get(q.placeId) ?? {};
  const doc = {
    name: q.name ?? place.name,
    letter: q.letter,
    order: q.order,
    lat: q.lat ?? place.lat,
    lon: q.lon ?? place.lon,
  };
  const missing = Object.entries(doc).filter(([, v]) => v === undefined || v === null);
  if (missing.length) {
    fail(`quest place ${q.placeId}: missing ${missing.map(([k]) => k).join(', ')} ` +
      `(not in ${opts.quest} and not found in ${opts.places})`);
  }
  if (q.placeId.includes('_')) fail(`placeId ${q.placeId} must not contain "_" (visit ids use it)`);
  return { placeId: q.placeId, ...doc };
});
if (questPlaces.length !== 7) {
  console.warn(`seed: warning: ${questPlaces.length} quest places, the spec expects 7`);
}

const codesPath = resolve(repoRoot, opts.codes);
const oldCodes = new Map();
if (existsSync(codesPath) && !opts['new-codes']) {
  for (const p of JSON.parse(readFileSync(codesPath, 'utf8')).places ?? []) oldCodes.set(p.placeId, p.code);
}
const newCode = () => Array.from({ length: CODE_LENGTH }, () => CODE_ALPHABET[randomInt(CODE_ALPHABET.length)]).join('');
const codes = new Map(questPlaces.map((p) => [p.placeId, oldCodes.get(p.placeId) ?? newCode()]));

const questId = quest.questId ?? DEFAULT_QUEST_ID;

// ---- Firestore REST -------------------------------------------------------------

const real = Boolean(opts.token);
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST ?? 'localhost:8080';
const base = real
  ? `https://firestore.googleapis.com/v1/projects/${opts.project}/databases/(default)/documents`
  : `http://${emulatorHost}/v1/projects/${opts.project}/databases/(default)/documents`;
const headers = {
  'Content-Type': 'application/json',
  // "owner" bypasses security rules in the emulator.
  Authorization: `Bearer ${real ? opts.token : 'owner'}`,
  ...(real ? { 'x-goog-user-project': opts.project } : {}),
};

function toValue(v) {
  if (v === null) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Number.isInteger(v)) return { integerValue: String(v) };
  if (typeof v === 'number') return { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  return { mapValue: { fields: toFields(v) } };
}

function toFields(obj) {
  return Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, toValue(v)]));
}

/** Writes a document. createOnly: skip it if it already exists. */
async function write(path, data, { createOnly = false } = {}) {
  if (opts['dry-run']) {
    console.log(`  [dry-run] ${createOnly ? 'create' : 'set'} ${path} ${JSON.stringify(data)}`);
    return;
  }
  const url = `${base}/${path}${createOnly ? '?currentDocument.exists=false' : ''}`;
  let res;
  try {
    res = await fetch(url, { method: 'PATCH', headers, body: JSON.stringify({ fields: toFields(data) }) });
  } catch (e) {
    fail(`cannot reach ${real ? 'Firestore' : `the emulator at ${emulatorHost}`} (${e.cause?.code ?? e.message}).` +
      (real ? '' : '\n  Start it: firebase emulators:start --only auth,firestore'));
  }
  if (res.ok) {
    console.log(`  set ${path}`);
    return;
  }
  const body = await res.text();
  if (createOnly && (res.status === 409 || body.includes('FAILED_PRECONDITION') || body.includes('ALREADY_EXISTS'))) {
    console.log(`  kept ${path} (exists; --force overwrites)`);
    return;
  }
  fail(`${path}: HTTP ${res.status} ${body}`);
}

console.log(`seed: ${real ? 'REAL project' : `emulator ${emulatorHost}`}, project ${opts.project}, quest ${questId}`);

const keep = { createOnly: !opts.force };
await write('config/game', { heatOverride: 0, activeQuestId: questId }, keep);
for (const [id, name] of Object.entries(DISTRICTS)) {
  await write(`districts/${id}`, { name, points: 0 }, keep);
}
for (const { placeId, ...doc } of questPlaces) {
  await write(`questPlaces/${placeId}`, doc);
  await write(`questCodes/${placeId}`, { code: codes.get(placeId) });
}

if (!opts['dry-run']) {
  mkdirSync(dirname(codesPath), { recursive: true });
  const out = {
    questId,
    password: quest.password ?? null,
    generatedAt: new Date().toISOString(),
    places: questPlaces.map((p) => ({
      placeId: p.placeId,
      name: p.name,
      letter: p.letter,
      order: p.order,
      code: codes.get(p.placeId),
      link: `coollodz://quest/${p.placeId}?c=${codes.get(p.placeId)}`,
    })),
  };
  writeFileSync(codesPath, `${JSON.stringify(out, null, 2)}\n`);
  console.log(`seed: codes written to ${codesPath} (keep it out of git)`);
}
console.log('seed: done');
