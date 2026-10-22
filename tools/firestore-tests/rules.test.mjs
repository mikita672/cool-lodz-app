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
  deleteField,
  deleteDoc,
  doc,
  getDoc,
  getCountFromServer,
  getDocs,
  increment,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
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

// The exact writes the app makes (FirestoreUserProfileRepository).
describe('users: app writes (S02 register, S03 consents, S04 profile)', () => {
  test('register, then consents, then profile, each as a merge', async () => {
    const alice = db('alice');
    const ref = doc(alice, 'users/alice');
    // createProfile (S02)
    await assertSucceeds(
      setDoc(ref, { nickname: 'cienista_ania', points: 0, weekPoints: 0, badges: [], createdAt: serverTimestamp() }, { merge: true }),
    );
    // saveConsents (S03)
    await assertSucceeds(
      setDoc(ref, { consents: { location: true, push: true, ranking: false, acceptedAt: serverTimestamp() } }, { merge: true }),
    );
    // saveComfortProfile (S04), weights are integers 0..100
    await assertSucceeds(
      setDoc(ref, { profile: { id: 'senior', weights: { shade: 90, time: 20, quiet: 60, air: 60 }, seniorMode: true } }, { merge: true }),
    );
    // Changing the profile later (Profil → «Mój profil komfortu»).
    await assertSucceeds(
      setDoc(ref, { profile: { id: 'default', weights: { shade: 60, time: 60, quiet: 30, air: 30 }, seniorMode: false } }, { merge: true }),
    );
    const saved = (await getDoc(ref)).data();
    assert.equal(saved.profile.id, 'default');
    assert.equal(saved.nickname, 'cienista_ania');
  });

  test('profile with unknown keys is rejected', async () => {
    await seed({ 'users/alice': user() });
    await assertFails(
      setDoc(doc(db('alice'), 'users/alice'), { profile: { id: 'senior', weights: {}, seniorMode: true, age: 70 } }, { merge: true }),
    );
  });
});

// The exact batches FirestoreGameRepository.award writes.
describe('game award batches (APP-16)', () => {
  async function award(uid, before, entries, week = '2026-W43') {
    const d = db(uid);
    const sum = entries.reduce((a, e) => a + e.points, 0);
    const batch = writeBatch(d);
    for (const e of entries) {
      batch.set(doc(collection(d, `users/${uid}/pointsLog`)), {
        type: e.type, points: e.points, refId: e.refId ?? null, createdAt: serverTimestamp(),
      });
    }
    const points = before.points + sum;
    const weekPoints = (before.weekId === week ? before.weekPoints : 0) + sum;
    const badges = [...new Set([...before.badges, ...(entries.badges ?? [])])];
    batch.update(doc(d, `users/${uid}`), { points, weekId: week, weekPoints, badges });
    if (before.consents.ranking) {
      batch.set(doc(d, `rankings/${uid}`), {
        nickname: before.nickname, district: before.district ?? null,
        points, weekId: week, weekPoints, updatedAt: serverTimestamp(),
      });
    }
    if (before.district) {
      batch.update(doc(d, `districts/${before.district}`), { points: increment(sum) });
      batch.set(doc(d, `districts/${before.district}/weeks/${week}`), { points: increment(sum) }, { merge: true });
    }
    await batch.commit();
    return { ...before, points, weekId: week, weekPoints, badges };
  }

  test('route + badge with ranking and district, then password split in two', async () => {
    let alice = user({ consents: { location: true, push: false, ranking: true, acceptedAt: new Date() }, weekId: '2026-W42', weekPoints: 90, points: 90 });
    await seed({ 'users/alice': alice, 'rankings/alice': { nickname: 'Ala', district: 'polesie', points: 90, weekId: '2026-W42', weekPoints: 90, updatedAt: new Date() } });
    const route = [{ type: 'route', points: 10 }, { type: 'badge', points: 30, refId: 'firstStep' }];
    route.badges = ['firstStep'];
    alice = await assertSucceeds(award('alice', alice, route));
    alice = await assertSucceeds(award('alice', alice, [{ type: 'password', points: 200, refId: 'chlodne-haslo-2026' }]));
    alice = await assertSucceeds(award('alice', alice, [{ type: 'badge', points: 30, refId: 'coolGuard' }]));
    const u = (await getDoc(doc(db('alice'), 'users/alice'))).data();
    assert.equal(u.points, 360);
    assert.equal(u.weekPoints, 270); // new week: reset, then 40 + 200 + 30
    const district = (await getDoc(doc(db('alice'), 'districts/polesie'))).data();
    assert.equal(district.points, 270);
    const week = (await getDoc(doc(db('alice'), 'districts/polesie/weeks/2026-W43'))).data();
    assert.equal(week.points, 270);
    const r = (await getDoc(doc(db('bob'), 'rankings/alice'))).data();
    assert.equal(r.points, 360);
  });

  test('password and badge in one write (230) is rejected', async () => {
    const alice = user();
    await seed({ 'users/alice': alice });
    await assertFails(award('alice', alice, [
      { type: 'password', points: 200, refId: 'q' },
      { type: 'badge', points: 30, refId: 'coolGuard' },
    ]));
  });

  test('without district and ranking only the user doc and log change', async () => {
    const alice = user({ district: null });
    await seed({ 'users/alice': alice });
    await assertSucceeds(award('alice', alice, [{ type: 'scan', points: 50, refId: 'cool-002' }]));
  });
});

// The exact writes of FirestoreAccountRepository (S16).
describe('account settings and removal (APP-19)', () => {
  const ranked = () => user({
    nickname: 'Ala', district: 'polesie', points: 300, weekId: '2026-W43', weekPoints: 120,
    consents: { location: true, push: true, ranking: true, acceptedAt: new Date() }, fcmToken: 'tok',
  });
  const mirrorOf = (u) => ({
    nickname: u.nickname, district: u.district ?? null, points: u.points,
    weekId: u.weekId ?? null, weekPoints: u.weekPoints, updatedAt: serverTimestamp(),
  });

  test('district change keeps the ranking copy in step', async () => {
    const u = ranked();
    await seed({ 'users/alice': u, 'rankings/alice': { ...mirrorOf(u), updatedAt: new Date() } });
    const d = db('alice');
    const batch = writeBatch(d);
    batch.update(doc(d, 'users/alice'), { district: 'widzew' });
    batch.set(doc(d, 'rankings/alice'), mirrorOf({ ...u, district: 'widzew' }));
    await assertSucceeds(batch.commit());
    // Without the copy the ranking would show the old district: rejected.
    const lone = writeBatch(d);
    lone.update(doc(d, 'users/alice'), { district: 'gorna' });
    lone.set(doc(d, 'rankings/alice'), mirrorOf({ ...u, district: 'widzew' }));
    await assertFails(lone.commit());
  });

  test('withdrawing ranking and push: ranking copy and token go away', async () => {
    const u = ranked();
    await seed({ 'users/alice': u, 'rankings/alice': { ...mirrorOf(u), updatedAt: new Date() } });
    const d = db('alice');
    const batch = writeBatch(d);
    batch.update(doc(d, 'users/alice'), {
      'consents.location': true, 'consents.push': false, 'consents.ranking': false, fcmToken: deleteField(),
    });
    batch.delete(doc(d, 'rankings/alice'));
    await assertSucceeds(batch.commit());
    const after = (await getDoc(doc(d, 'users/alice'))).data();
    assert.equal(after.consents.ranking, false);
    assert.equal(after.fcmToken, undefined);
  });

  test('opting in publishes the copy in the same batch', async () => {
    const u = { ...ranked(), consents: { location: true, push: false, ranking: false, acceptedAt: new Date() } };
    await seed({ 'users/alice': u });
    const d = db('alice');
    const batch = writeBatch(d);
    batch.update(doc(d, 'users/alice'), { 'consents.location': true, 'consents.push': false, 'consents.ranking': true });
    batch.set(doc(d, 'rankings/alice'), mirrorOf(u));
    await assertSucceeds(batch.commit());
  });

  test('«Usuń konto» deletes every document of the user', async () => {
    const day = todayPl();
    await seed({
      'users/alice': ranked(),
      'rankings/alice': { ...mirrorOf(ranked()), updatedAt: new Date() },
      'users/alice/pointsLog/l1': { type: 'scan', points: 50, refId: PLACE, createdAt: new Date() },
      'users/alice/routes/r1': { variant: 'shaded', sunShare: 0.2, createdAt: new Date() },
      [`visits/alice_${PLACE}_${day}`]: { uid: 'alice', placeId: PLACE, code: CODE, createdAt: new Date() },
      'reports/rep1': { ...report('alice'), createdAt: new Date() },
      'users/bob': user({ nickname: 'Bob' }),
    });
    const d = db('alice');
    const refs = [];
    for (const sub of ['pointsLog', 'routes']) {
      const q = await assertSucceeds(getDocs(collection(d, `users/alice/${sub}`)));
      refs.push(...q.docs.map((x) => x.ref));
    }
    for (const col of ['visits', 'reports']) {
      const q = await assertSucceeds(getDocs(query(collection(d, col), where('uid', '==', 'alice'))));
      refs.push(...q.docs.map((x) => x.ref));
    }
    refs.push(doc(d, 'rankings/alice'), doc(d, 'users/alice'));
    assert.equal(refs.length, 6);
    const batch = writeBatch(d);
    for (const r of refs) batch.delete(r);
    await assertSucceeds(batch.commit());
    await env.withSecurityRulesDisabled(async (ctx) => {
      const admin = ctx.firestore();
      assert.equal((await getDoc(doc(admin, 'users/alice'))).exists(), false);
      assert.equal((await getDocs(collection(admin, 'users/alice/pointsLog'))).size, 0);
      assert.equal((await getDoc(doc(admin, 'reports/rep1'))).exists(), false);
      assert.equal((await getDoc(doc(admin, 'users/bob'))).exists(), true);
    });
  });
});

describe('ranking (rankings/{uid})', () => {
  const optedIn = (overrides = {}) =>
    user({ points: 300, weekPoints: 120, consents: { ranking: true }, ...overrides });
  const mirror = (u) => ({
    nickname: u.nickname,
    district: u.district,
    points: u.points,
    weekId: u.weekId,
    weekPoints: u.weekPoints,
    updatedAt: serverTimestamp(),
  });

  test('other users can read rankings but not users', async () => {
    await seed({
      'users/alice': optedIn(),
      'rankings/alice': { ...mirror(optedIn()), updatedAt: new Date() },
    });
    await assertSucceeds(getDoc(doc(db('bob'), 'rankings/alice')));
    await assertFails(getDoc(doc(db('bob'), 'users/alice')));
    await assertFails(getDocs(query(collection(db('bob'), 'users'), where('consents.ranking', '==', true))));
  });

  test('owner writes a ranking doc that mirrors the user doc', async () => {
    await seed({ 'users/alice': optedIn() });
    await assertSucceeds(setDoc(doc(db('alice'), 'rankings/alice'), mirror(optedIn())));
  });

  test('ranking doc that does not mirror the user doc is rejected', async () => {
    await seed({ 'users/alice': optedIn() });
    const ref = doc(db('alice'), 'rankings/alice');
    await assertFails(setDoc(ref, { ...mirror(optedIn()), points: 9999 }));
    await assertFails(setDoc(ref, { ...mirror(optedIn()), weekPoints: 121 }));
    await assertFails(setDoc(ref, { ...mirror(optedIn()), nickname: 'Fake' }));
    await assertFails(setDoc(ref, { ...mirror(optedIn()), weekId: '2026-W44' }));
    await assertFails(setDoc(ref, { ...mirror(optedIn()), badges: [] }));
    await assertFails(setDoc(ref, { ...mirror(optedIn()), updatedAt: new Date(0) }));
  });

  test('points update and ranking update in one batch', async () => {
    await seed({
      'users/alice': optedIn(),
      'rankings/alice': { ...mirror(optedIn()), updatedAt: new Date() },
    });
    const alice = db('alice');
    const after = optedIn({ points: 350, weekPoints: 170 });
    const ok = writeBatch(alice);
    ok.update(doc(alice, 'users/alice'), { points: 350, weekPoints: 170 });
    ok.set(doc(alice, 'rankings/alice'), mirror(after));
    await assertSucceeds(ok.commit());
    // Ranking ahead of the user doc (no user update in the batch).
    await assertFails(setDoc(doc(alice, 'rankings/alice'), mirror(optedIn({ points: 400, weekPoints: 220 }))));
  });

  test('write without the ranking consent is rejected', async () => {
    const u = user({ consents: { ranking: false } });
    await seed({ 'users/alice': u });
    await assertFails(setDoc(doc(db('alice'), 'rankings/alice'), mirror(u)));
  });

  test('opting in and creating the ranking doc can be one batch', async () => {
    await seed({ 'users/alice': user({ consents: { ranking: false } }) });
    const alice = db('alice');
    const b = writeBatch(alice);
    b.update(doc(alice, 'users/alice'), { 'consents.ranking': true });
    b.set(doc(alice, 'rankings/alice'), mirror(user()));
    await assertSucceeds(b.commit());
  });

  test('withdrawing consent must delete the ranking doc in the same batch', async () => {
    await seed({
      'users/alice': optedIn(),
      'rankings/alice': { ...mirror(optedIn()), updatedAt: new Date() },
    });
    const alice = db('alice');
    await assertFails(updateDoc(doc(alice, 'users/alice'), { 'consents.ranking': false }));
    const b = writeBatch(alice);
    b.update(doc(alice, 'users/alice'), { 'consents.ranking': false });
    b.delete(doc(alice, 'rankings/alice'));
    await assertSucceeds(b.commit());
  });

  test('owner can delete own ranking doc, others cannot', async () => {
    await seed({ 'rankings/alice': { ...mirror(optedIn()), updatedAt: new Date() } });
    await assertFails(deleteDoc(doc(db('bob'), 'rankings/alice')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'rankings/alice')));
  });

  test('another user cannot write my ranking doc', async () => {
    await seed({ 'users/alice': optedIn() });
    await assertFails(setDoc(doc(db('bob'), 'rankings/alice'), mirror(optedIn())));
  });

  test('all-time and weekly leaderboard queries work', async () => {
    await seed({
      'rankings/alice': { ...mirror(optedIn()), updatedAt: new Date() },
      'rankings/dave': { ...mirror(optedIn({ nickname: 'Dawid', points: 50, weekId: '2026-W42', weekPoints: 50 })), updatedAt: new Date() },
    });
    const col = collection(db('bob'), 'rankings');
    const all = await assertSucceeds(getDocs(query(col, orderBy('points', 'desc'), limit(50))));
    assert.deepEqual(all.docs.map((d) => d.id), ['alice', 'dave']);
    const week = await assertSucceeds(
      getDocs(query(col, where('weekId', '==', '2026-W43'), orderBy('weekPoints', 'desc'), limit(50))),
    );
    assert.deepEqual(week.docs.map((d) => d.id), ['alice']);
  });

  test('rank of the pinned own row: count of users with more points', async () => {
    await seed({
      'rankings/alice': { ...mirror(optedIn()), updatedAt: new Date() },
      'rankings/dave': { ...mirror(optedIn({ nickname: 'Dawid', points: 50, weekId: '2026-W42', weekPoints: 50 })), updatedAt: new Date() },
    });
    const col = collection(db('bob'), 'rankings');
    const above = await assertSucceeds(getCountFromServer(query(col, where('points', '>', 10))));
    assert.equal(above.data().count, 2);
    const weekAbove = await assertSucceeds(
      getCountFromServer(query(col, where('weekId', '==', '2026-W43'), where('weekPoints', '>', 0))),
    );
    assert.equal(weekAbove.data().count, 1);
    await assertFails(getCountFromServer(query(collection(db(null), 'rankings'), where('points', '>', 0))));
  });

  test('unauthenticated users cannot read rankings', async () => {
    await assertFails(getDocs(collection(db(null), 'rankings')));
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

  test('routes: the impact fields are optional and checked', async () => {
    const col = 'users/alice/routes';
    const alice = db('alice');
    const base = { variant: 'shaded', sunShare: 0.28, distance_m: 2140, createdAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(alice, `${col}/a`),
      { ...base, duration_s: 1500, shortestSunShare: 0.61, waterStops: 2 }));
    await assertFails(setDoc(doc(alice, `${col}/b`), { ...base, shortestSunShare: 1.5 }));
    await assertFails(setDoc(doc(alice, `${col}/c`), { ...base, duration_s: -1 }));
    await assertFails(setDoc(doc(alice, `${col}/d`), { ...base, waterStops: 'two' }));
    await assertFails(setDoc(doc(alice, `${col}/e`), { ...base, extra: 1 }));
  });
});

describe('shop (redemptions)', () => {
  const redemption = (cost = 300) => ({
    rewardId: 'mpk20', cost, code: 'MPK-ABCD-1234', createdAt: serverTimestamp(),
  });

  test('buying: spent grows by the cost in the same batch', async () => {
    await seed({ 'users/alice': user({ points: 1000 }) });
    const alice = db('alice');
    const batch = writeBatch(alice);
    batch.update(doc(alice, 'users/alice'), { spent: 300 });
    batch.set(doc(alice, 'users/alice/redemptions/r1'), redemption(300));
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(alice, 'users/alice/redemptions/r1')));
    await assertFails(updateDoc(doc(alice, 'users/alice/redemptions/r1'), { cost: 1 }));
    await assertFails(getDoc(doc(db('bob'), 'users/alice/redemptions/r1')));
  });

  test('a redemption without paying, or paying less, is rejected', async () => {
    await seed({ 'users/alice': user({ points: 1000 }) });
    const alice = db('alice');
    await assertFails(setDoc(doc(alice, 'users/alice/redemptions/r1'), redemption(300)));
    const batch = writeBatch(alice);
    batch.update(doc(alice, 'users/alice'), { spent: 100 });
    batch.set(doc(alice, 'users/alice/redemptions/r2'), redemption(300));
    await assertFails(batch.commit());
  });

  test('spent never goes down and never above points', async () => {
    await seed({ 'users/alice': user({ points: 500, spent: 300 }) });
    const ref = doc(db('alice'), 'users/alice');
    await assertFails(updateDoc(ref, { spent: 200 }));
    await assertFails(updateDoc(ref, { spent: 600 }));
    await assertSucceeds(updateDoc(ref, { spent: 500 }));
  });

  test('a new user starts with nothing spent', async () => {
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), user({ spent: 100 })));
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

const crowd = (uid, overrides = {}) => ({
  uid,
  kind: 'tree',
  lat: 51.7592,
  lon: 19.4560,
  note: 'Brak cienia przy przystanku',
  votes: 0,
  createdAt: serverTimestamp(),
  ...overrides,
});

describe('crowd points', () => {
  test('signed-in user adds a tree or tap point in Łódź', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'crowdPoints/t1'), crowd('alice')));
    await assertSucceeds(setDoc(doc(db('alice'), 'crowdPoints/t2'), crowd('alice', { kind: 'tap' })));
    await assertSucceeds(getDoc(doc(db('bob'), 'crowdPoints/t1')));
    await assertFails(getDoc(doc(db(null), 'crowdPoints/t1')));
  });

  test('invalid points are rejected', async () => {
    const alice = db('alice');
    await assertFails(setDoc(doc(alice, 'crowdPoints/a'), crowd('bob')));
    await assertFails(setDoc(doc(alice, 'crowdPoints/b'), crowd('alice', { kind: 'bench' })));
    await assertFails(setDoc(doc(alice, 'crowdPoints/c'), crowd('alice', { lat: 52.23 })));
    await assertFails(setDoc(doc(alice, 'crowdPoints/d'), crowd('alice', { votes: 5 })));
    await assertFails(setDoc(doc(alice, 'crowdPoints/e'), crowd('alice', { note: 'x'.repeat(121) })));
    await assertFails(setDoc(doc(alice, 'crowdPoints/f'), crowd('alice', { extra: 1 })));
    await assertFails(setDoc(doc(db(null), 'crowdPoints/g'), crowd('alice')));
  });

  test('one vote per user, in a batch with votes + 1', async () => {
    await seed({ 'crowdPoints/p1': { ...crowd('alice'), createdAt: new Date() } });
    const bob = db('bob');
    const vote = () => {
      const b = writeBatch(bob);
      b.set(doc(bob, 'crowdPoints/p1/votes/bob'), { createdAt: serverTimestamp() });
      b.update(doc(bob, 'crowdPoints/p1'), { votes: increment(1) });
      return b.commit();
    };
    await assertSucceeds(vote());
    await assertFails(vote());
    let votes;
    await env.withSecurityRulesDisabled(async (ctx) => {
      votes = (await getDoc(doc(ctx.firestore(), 'crowdPoints/p1'))).data().votes;
    });
    assert.equal(votes, 1);
  });

  test('votes cannot jump, and other fields cannot change', async () => {
    await seed({ 'crowdPoints/p1': { ...crowd('alice'), createdAt: new Date() } });
    const bob = db('bob');
    await assertFails(updateDoc(doc(bob, 'crowdPoints/p1'), { votes: increment(1) }));
    const b = writeBatch(bob);
    b.set(doc(bob, 'crowdPoints/p1/votes/bob'), { createdAt: serverTimestamp() });
    b.update(doc(bob, 'crowdPoints/p1'), { votes: increment(2) });
    await assertFails(b.commit());
    const c = writeBatch(bob);
    c.set(doc(bob, 'crowdPoints/p1/votes/carol'), { createdAt: serverTimestamp() });
    c.update(doc(bob, 'crowdPoints/p1'), { votes: increment(1) });
    await assertFails(c.commit());
    await assertFails(updateDoc(doc(db('alice'), 'crowdPoints/p1'), { note: 'edited' }));
  });

  test('only the author deletes a point', async () => {
    await seed({ 'crowdPoints/p1': { ...crowd('alice'), createdAt: new Date() } });
    await assertFails(deleteDoc(doc(db('bob'), 'crowdPoints/p1')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'crowdPoints/p1')));
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
