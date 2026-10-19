// Firestore security rules tests. Run inside the emulator:
//   firebase emulators:exec --only firestore --project demo-coollodz \
//     "npm --prefix tools/firestore-tests test"
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-coollodz';
const PLACE = 'cool-002';
const CODE = 'K7M2QX';

let env;

/** Today's date in Poland as yyyyMMdd (same as visitId() in the app). */
function todayPl(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Warsaw',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const get = (t) => parts.find((p) => p.type === t).value;
  return `${get('year')}${get('month')}${get('day')}`;
}

const db = (uid) =>
  uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();

/** Writes documents with rules disabled (like the seed / the console). */
async function seed(docs) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    for (const [path, data] of Object.entries(docs)) {
      await setDoc(doc(admin, path), data);
    }
  });
}

const user = (overrides = {}) => ({
  nickname: 'Ala',
  district: 'polesie',
  profile: { id: 'senior', weights: { shade: 0.8 }, seniorMode: true },
  consents: { location: true, push: false, ranking: false, acceptedAt: new Date() },
  points: 0,
  weekId: '2026-W43',
  weekPoints: 0,
  badges: [],
  ...overrides,
});

const visit = (uid, overrides = {}) => ({
  uid,
  placeId: PLACE,
  code: CODE,
  lat: 51.7791,
  lon: 19.4439,
  createdAt: serverTimestamp(),
  ...overrides,
});

const report = (uid, overrides = {}) => ({
  uid,
  type: 'noShade',
  lat: 51.76,
  lon: 19.46,
  comment: 'Brak drzew przy przystanku',
  status: 'new',
  createdAt: serverTimestamp(),
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await seed({
    'config/game': { heatOverride: 0, activeQuestId: 'chlodne-haslo-2026' },
    [`questPlaces/${PLACE}`]: { name: 'Manufaktura', letter: 'C', order: 1, lat: 51.7791, lon: 19.4439 },
    [`questCodes/${PLACE}`]: { code: CODE },
    'districts/polesie': { name: 'Polesie', points: 0 },
  });
});

describe('unauthenticated', () => {
  test('cannot read or write anything', async () => {
    await seed({ 'users/alice': user({ consents: { ranking: true } }) });
    const anon = db(null);
    await assertFails(getDoc(doc(anon, 'users/alice')));
    await assertFails(setDoc(doc(anon, 'users/anon'), user()));
    await assertFails(getDoc(doc(anon, 'config/game')));
    await assertFails(getDoc(doc(anon, `questPlaces/${PLACE}`)));
    await assertFails(getDoc(doc(anon, 'districts/polesie')));
    await assertFails(setDoc(doc(anon, 'reports/r1'), report('anon')));
  });
});

describe('users', () => {
  test('owner can create, read and update own document', async () => {
    const alice = db('alice');
    await assertSucceeds(setDoc(doc(alice, 'users/alice'), user()));
    await assertSucceeds(getDoc(doc(alice, 'users/alice')));
    await assertSucceeds(updateDoc(doc(alice, 'users/alice'), { nickname: 'Alicja', fcmToken: 'tok' }));
  });

  test('another user cannot read or write it', async () => {
    await seed({ 'users/alice': user() });
    const bob = db('bob');
    await assertFails(getDoc(doc(bob, 'users/alice')));
    await assertFails(updateDoc(doc(bob, 'users/alice'), { points: 10 }));
    await assertFails(setDoc(doc(bob, 'users/alice'), user()));
    await assertFails(deleteDoc(doc(bob, 'users/alice')));
  });

  test('unknown keys and bad nickname are rejected', async () => {
    const alice = db('alice');
    await assertFails(setDoc(doc(alice, 'users/alice'), user({ isAdmin: true })));
    await assertFails(setDoc(doc(alice, 'users/alice'), user({ nickname: 'A' })));
    await assertFails(setDoc(doc(alice, 'users/alice'), user({ nickname: 'x'.repeat(25) })));
    await assertFails(setDoc(doc(alice, 'users/alice'), user({ district: 'nowhere' })));
    await assertFails(setDoc(doc(alice, 'users/alice'), user({ profile: { id: 'x', hack: 1 } })));
  });

  test('points grow by at most 200 per write and never decrease', async () => {
    await seed({ 'users/alice': user({ points: 100, weekPoints: 100 }) });
    const ref = doc(db('alice'), 'users/alice');
    await assertSucceeds(updateDoc(ref, { points: 300, weekPoints: 300 }));
    await assertFails(updateDoc(ref, { points: 501 }));
    await assertFails(updateDoc(ref, { points: increment(201) }));
    await assertFails(updateDoc(ref, { points: 299 }));
    await assertFails(updateDoc(ref, { weekPoints: 299 }));
    await assertFails(updateDoc(ref, { weekPoints: 501 }));
  });

  test('a new weekId resets weekPoints', async () => {
    await seed({ 'users/alice': user({ points: 500, weekId: '2026-W43', weekPoints: 400 }) });
    const ref = doc(db('alice'), 'users/alice');
    await assertFails(updateDoc(ref, { weekId: '2026-W44', weekPoints: 201 }));
    await assertFails(updateDoc(ref, { weekId: 'next week', weekPoints: 0 }));
    await assertSucceeds(updateDoc(ref, { points: 550, weekId: '2026-W44', weekPoints: 50 }));
  });

  test('more than 200 points on create is rejected', async () => {
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), user({ points: 1000 })));
  });

  test('badges only grow', async () => {
    await seed({ 'users/alice': user({ badges: ['firstStep', 'coolGuard'] }) });
    const ref = doc(db('alice'), 'users/alice');
    await assertSucceeds(updateDoc(ref, { badges: ['firstStep', 'coolGuard', 'earlyBird'] }));
    await assertFails(updateDoc(ref, { badges: ['firstStep'] }));
  });

  test('owner can delete own document', async () => {
    await seed({ 'users/alice': user() });
    await assertSucceeds(deleteDoc(doc(db('alice'), 'users/alice')));
  });
});

describe('ranking', () => {
  beforeEach(async () => {
    await seed({
      'users/alice': user({ nickname: 'Ala', points: 300, consents: { ranking: true } }),
      'users/carol': user({ nickname: 'Karo', points: 900, consents: { ranking: false } }),
      'users/dave': user({ nickname: 'Dawid', points: 50, consents: { ranking: true }, weekId: '2026-W42' }),
    });
  });

  test('opted-in user documents are readable by signed-in users', async () => {
    await assertSucceeds(getDoc(doc(db('bob'), 'users/alice')));
  });

  test('users who did not opt in stay private', async () => {
    await assertFails(getDoc(doc(db('bob'), 'users/carol')));
  });

  test('all-time leaderboard query works and lists only opted-in users', async () => {
    const q = query(
      collection(db('bob'), 'users'),
      where('consents.ranking', '==', true),
      orderBy('points', 'desc'),
    );
    const snap = await assertSucceeds(getDocs(q));
    assert.deepEqual(snap.docs.map((d) => d.id), ['alice', 'dave']);
  });

  test('weekly leaderboard query works', async () => {
    const q = query(
      collection(db('bob'), 'users'),
      where('consents.ranking', '==', true),
      where('weekId', '==', '2026-W43'),
      orderBy('weekPoints', 'desc'),
    );
    const snap = await assertSucceeds(getDocs(q));
    assert.deepEqual(snap.docs.map((d) => d.id), ['alice']);
  });

  test('query without the ranking filter is rejected', async () => {
    await assertFails(getDocs(query(collection(db('bob'), 'users'), orderBy('points', 'desc'))));
  });

  test('unauthenticated ranking query is rejected', async () => {
    const q = query(collection(db(null), 'users'), where('consents.ranking', '==', true));
    await assertFails(getDocs(q));
  });
});

describe('pointsLog and routes', () => {
  test('owner creates a log entry; no updates; others denied', async () => {
    const ref = doc(db('alice'), 'users/alice/pointsLog/l1');
    const entry = { type: 'qrScan', points: 50, refId: `alice_${PLACE}_20261019`, createdAt: serverTimestamp() };
    await assertSucceeds(setDoc(ref, entry));
    await assertSucceeds(getDoc(ref));
    await assertFails(updateDoc(ref, { points: 60 }));
    await assertFails(setDoc(doc(db('bob'), 'users/alice/pointsLog/l2'), entry));
    await assertFails(getDoc(doc(db('bob'), 'users/alice/pointsLog/l1')));
  });

  test('log entry points must be 1..200 and createdAt server time', async () => {
    const col = 'users/alice/pointsLog';
    const alice = db('alice');
    const base = { type: 'qrScan', refId: null, createdAt: serverTimestamp() };
    await assertFails(setDoc(doc(alice, `${col}/a`), { ...base, points: 201 }));
    await assertFails(setDoc(doc(alice, `${col}/b`), { ...base, points: 0 }));
    await assertFails(setDoc(doc(alice, `${col}/c`), { ...base, points: 50, createdAt: new Date(0) }));
    await assertFails(setDoc(doc(alice, `${col}/d`), { ...base, points: 50, extra: 1 }));
  });

  test('routes: owner create, read, delete; no update; others denied', async () => {
    const ref = doc(db('alice'), 'users/alice/routes/r1');
    const route = { variant: 'shaded', sunShare: 0.28, distance_m: 2140, endPlaceType: 'park', createdAt: serverTimestamp() };
    await assertSucceeds(setDoc(ref, route));
    await assertSucceeds(getDoc(ref));
    await assertFails(updateDoc(ref, { sunShare: 0 }));
    await assertFails(getDoc(doc(db('bob'), 'users/alice/routes/r1')));
    await assertFails(setDoc(doc(db('bob'), 'users/alice/routes/r2'), route));
    await assertSucceeds(deleteDoc(ref));
  });
});

describe('visits (QR scans)', () => {
  const id = (uid = 'alice', day = todayPl()) => `visits/${uid}_${PLACE}_${day}`;

  test('first scan of the day with the right code succeeds', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), id()), visit('alice')));
  });

  test('second scan of the same place on the same day is rejected', async () => {
    const ref = doc(db('alice'), id());
    await assertSucceeds(setDoc(ref, visit('alice')));
    await assertFails(setDoc(ref, visit('alice')));
  });

  test('wrong code is rejected', async () => {
    await assertFails(setDoc(doc(db('alice'), id()), visit('alice', { code: 'WRONG1' })));
  });

  test('unknown place is rejected', async () => {
    const ref = doc(db('alice'), `visits/alice_cool-999_${todayPl()}`);
    await assertFails(setDoc(ref, visit('alice', { placeId: 'cool-999' })));
  });

  test('id must be uid_placeId_today', async () => {
    const alice = db('alice');
    await assertFails(setDoc(doc(alice, id('alice', '20200101')), visit('alice')));
    await assertFails(setDoc(doc(alice, `visits/alice_${PLACE}`), visit('alice')));
    await assertFails(setDoc(doc(alice, id('bob')), visit('bob')));
    await assertFails(setDoc(doc(alice, id('bob')), visit('alice')));
  });

  test('createdAt must be server time', async () => {
    await assertFails(setDoc(doc(db('alice'), id()), visit('alice', { createdAt: new Date() })));
  });

  test('owner can read and delete own visit, nobody else can', async () => {
    const path = id();
    await assertSucceeds(setDoc(doc(db('alice'), path), visit('alice')));
    await assertFails(getDoc(doc(db('bob'), path)));
    await assertFails(deleteDoc(doc(db('bob'), path)));
    await assertSucceeds(getDoc(doc(db('alice'), path)));
    await assertSucceeds(deleteDoc(doc(db('alice'), path)));
  });
});

describe('quest places and codes', () => {
  test('questPlaces readable by signed-in users, not writable', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), `questPlaces/${PLACE}`)));
    await assertFails(setDoc(doc(db('alice'), 'questPlaces/cool-100'), { name: 'X' }));
  });

  test('questCodes are not readable or writable by clients', async () => {
    await assertFails(getDoc(doc(db('alice'), `questCodes/${PLACE}`)));
    await assertFails(getDocs(collection(db('alice'), 'questCodes')));
    await assertFails(setDoc(doc(db('alice'), `questCodes/${PLACE}`), { code: 'AAAAAA' }));
  });
});

describe('districts', () => {
  test('signed-in users read districts and weeks', async () => {
    await seed({ 'districts/polesie/weeks/2026-W43': { name: 'Polesie', points: 10 } });
    await assertSucceeds(getDoc(doc(db('alice'), 'districts/polesie')));
    await assertSucceeds(getDoc(doc(db('alice'), 'districts/polesie/weeks/2026-W43')));
  });

  test('increment by 1..200 succeeds', async () => {
    await assertSucceeds(updateDoc(doc(db('alice'), 'districts/polesie'), { points: increment(200) }));
  });

  test('increment above 200, zero or negative is rejected', async () => {
    const ref = doc(db('alice'), 'districts/polesie');
    await assertFails(updateDoc(ref, { points: increment(201) }));
    await assertFails(updateDoc(ref, { points: increment(0) }));
    await assertFails(updateDoc(ref, { points: increment(-10) }));
  });

  test('other fields cannot change', async () => {
    await assertFails(updateDoc(doc(db('alice'), 'districts/polesie'), { name: 'Hacked', points: increment(1) }));
  });

  test('clients cannot create or delete districts', async () => {
    await assertFails(setDoc(doc(db('alice'), 'districts/nowe'), { name: 'Nowe', points: 0 }));
    await assertFails(deleteDoc(doc(db('alice'), 'districts/polesie')));
  });

  test('week doc: create with ≤ 200, then increments', async () => {
    const ref = doc(db('alice'), 'districts/polesie/weeks/2026-W43');
    await assertFails(setDoc(ref, { name: 'Polesie', points: 201 }));
    await assertSucceeds(setDoc(ref, { name: 'Polesie', points: increment(50) }, { merge: true }));
    await assertSucceeds(setDoc(ref, { points: increment(200) }, { merge: true }));
    await assertFails(setDoc(ref, { points: increment(201) }, { merge: true }));
  });

  test('week doc: bad week id or unknown district rejected', async () => {
    await assertFails(setDoc(doc(db('alice'), 'districts/polesie/weeks/43'), { points: 10 }));
    await assertFails(setDoc(doc(db('alice'), 'districts/nowe/weeks/2026-W43'), { points: 10 }));
  });
});

describe('reports', () => {
  test('author creates a report with status new', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'reports/r1'), report('alice')));
  });

  test('invalid reports are rejected', async () => {
    const alice = db('alice');
    await assertFails(setDoc(doc(alice, 'reports/a'), report('alice', { status: 'approved' })));
    await assertFails(setDoc(doc(alice, 'reports/b'), report('bob')));
    await assertFails(setDoc(doc(alice, 'reports/c'), report('alice', { type: 'graffiti' })));
    await assertFails(setDoc(doc(alice, 'reports/d'), report('alice', { comment: 'x'.repeat(201) })));
    await assertFails(setDoc(doc(alice, 'reports/e'), report('alice', { lat: '51.7' })));
  });

  test('status cannot be changed by the client', async () => {
    const ref = doc(db('alice'), 'reports/r1');
    await assertSucceeds(setDoc(ref, report('alice')));
    await assertFails(updateDoc(ref, { status: 'approved' }));
    await assertFails(updateDoc(ref, { comment: 'edited' }));
  });

  test('author reads and deletes own report; others cannot', async () => {
    await seed({ 'reports/r1': { ...report('alice'), createdAt: new Date() } });
    await assertFails(getDoc(doc(db('bob'), 'reports/r1')));
    await assertFails(deleteDoc(doc(db('bob'), 'reports/r1')));
    await assertSucceeds(getDoc(doc(db('alice'), 'reports/r1')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'reports/r1')));
  });
});

describe('config and default deny', () => {
  test('config/game readable by signed-in users, not writable', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'config/game')));
    await assertFails(updateDoc(doc(db('alice'), 'config/game'), { heatOverride: 3 }));
  });

  test('other config docs and unknown collections are denied', async () => {
    await assertFails(getDoc(doc(db('alice'), 'config/secret')));
    await assertFails(setDoc(doc(db('alice'), 'anything/x'), { a: 1 }));
    await assertFails(getDoc(doc(db('alice'), 'anything/x')));
  });
});
