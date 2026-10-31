// Security rules tests. Run from firestore-tests/: npm test
// (starts the Firestore emulator for project demo-pcu, no real data involved).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs } from 'firebase/firestore';

let env;

const ADMIN = 'boss@x.com';
const DAVID = 'david@x.com';
const ADA = 'ada@x.com';
const PAUSED = 'paused@x.com';

// Token claims for a signed-in Google user.
const as = (email, verified = true) =>
  env.authenticatedContext(email.replace(/\W/g, ''), { email, email_verified: verified }).firestore();

const followUp = (over = {}) => ({
  guestId: 'G1',
  worker: DAVID,
  loggedBy: DAVID,
  callDate: '2026-10-30',
  month: '2026-10',
  outcome: 'Reached',
  note: 'Lovely chat',
  attendedSunday: false,
  attendedWednesday: false,
  team: '',
  points: 10,
  syncedToSheet: false,
  createdAt: new Date(),
  ...over,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-pcu',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8085 },
  });
});

after(async () => env && env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', ADMIN), { name: 'Boss', email: ADMIN, role: 'admin', active: true });
    await setDoc(doc(db, 'users', DAVID), { name: 'David', email: DAVID, role: 'worker', active: true });
    await setDoc(doc(db, 'users', ADA), { name: 'Ada', email: ADA, role: 'worker', active: true });
    await setDoc(doc(db, 'users', PAUSED), { name: 'Paused', email: PAUSED, role: 'worker', active: false });
    await setDoc(doc(db, 'guests', 'G1'), {
      name: 'Guest One', phone: '0803', month: '2026-10', assignedTo: DAVID, followUpCount: 0,
    });
    await setDoc(doc(db, 'guests', 'G2'), {
      name: 'Guest Two', phone: '0804', month: '2026-10', assignedTo: ADA, followUpCount: 0,
    });
    await setDoc(doc(db, 'followUps', 'F1'), followUp());
    await setDoc(doc(db, 'meta', 'sync'), { lastSheetSyncAt: new Date() });
  });
});

describe('sign in', () => {
  test('signed out users read nothing', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'guests', 'G1')));
  });
  test('unverified email is refused', async () => {
    await assertFails(getDoc(doc(as(DAVID, false), 'guests', 'G1')));
  });
  test('someone not in users is refused', async () => {
    await assertFails(getDoc(doc(as('stranger@x.com'), 'guests', 'G1')));
  });
  test('an inactive worker is refused', async () => {
    await assertFails(getDoc(doc(as(PAUSED), 'users', PAUSED)));
  });
  test('email case and spaces do not matter', async () => {
    await assertSucceeds(getDoc(doc(as('David@X.com'), 'guests', 'G1')));
  });
});

describe('users and meta', () => {
  test('a worker reads their own user doc only', async () => {
    await assertSucceeds(getDoc(doc(as(DAVID), 'users', DAVID)));
    await assertFails(getDoc(doc(as(DAVID), 'users', ADA)));
  });
  test('admin reads any user', async () => {
    await assertSucceeds(getDoc(doc(as(ADMIN), 'users', DAVID)));
  });
  test('nobody writes users or meta from the app', async () => {
    await assertFails(setDoc(doc(as(ADMIN), 'users', 'new@x.com'), { role: 'admin', active: true }));
    await assertFails(updateDoc(doc(as(DAVID), 'users', DAVID), { role: 'admin' }));
    await assertFails(setDoc(doc(as(ADMIN), 'meta', 'sync'), { running: true }));
  });
  test('only admin reads meta', async () => {
    await assertSucceeds(getDoc(doc(as(ADMIN), 'meta', 'sync')));
    await assertFails(getDoc(doc(as(DAVID), 'meta', 'sync')));
  });
});

describe('guests', () => {
  test('a worker reads only their own guests', async () => {
    await assertSucceeds(getDoc(doc(as(DAVID), 'guests', 'G1')));
    await assertFails(getDoc(doc(as(DAVID), 'guests', 'G2')));
  });
  test('a worker query must be limited to their guests', async () => {
    const db = as(DAVID);
    await assertSucceeds(getDocs(query(collection(db, 'guests'), where('assignedTo', '==', DAVID))));
    await assertFails(getDocs(collection(db, 'guests')));
  });
  test('admin reads all guests', async () => {
    await assertSucceeds(getDocs(collection(as(ADMIN), 'guests')));
  });
  test('nobody creates or deletes guests from the app', async () => {
    await assertFails(setDoc(doc(as(ADMIN), 'guests', 'G9'), { name: 'X', assignedTo: DAVID }));
    await assertFails(deleteDoc(doc(as(ADMIN), 'guests', 'G1')));
  });
  test('a worker updates work fields on their own guest', async () => {
    await assertSucceeds(updateDoc(doc(as(DAVID), 'guests', 'G1'), { followUpCount: 1, callStatus: 'Reached' }));
  });
  test('sheet-owned fields can never be changed from the app', async () => {
    await assertFails(updateDoc(doc(as(DAVID), 'guests', 'G1'), { assignedTo: ADA }));
    await assertFails(updateDoc(doc(as(DAVID), 'guests', 'G1'), { name: 'Renamed' }));
    await assertFails(updateDoc(doc(as(ADMIN), 'guests', 'G1'), { phone: '000' }));
  });
  test('a worker cannot touch someone else\'s guest', async () => {
    await assertFails(updateDoc(doc(as(DAVID), 'guests', 'G2'), { followUpCount: 1 }));
  });
});

describe('follow-ups', () => {
  test('a worker logs for their own guest', async () => {
    await assertSucceeds(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp()));
  });
  test('a worker cannot log for another worker\'s guest', async () => {
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ guestId: 'G2', worker: ADA })));
  });
  test('a worker cannot credit someone else or pretend someone else logged it', async () => {
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ worker: ADA })));
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ loggedBy: ADMIN })));
  });
  test('admin logs on behalf of the assigned worker', async () => {
    await assertSucceeds(setDoc(doc(as(ADMIN), 'followUps', 'F2'), followUp({ loggedBy: ADMIN })));
  });
  test('admin cannot credit themselves or the wrong worker', async () => {
    await assertFails(setDoc(doc(as(ADMIN), 'followUps', 'F2'), followUp({ worker: ADMIN, loggedBy: ADMIN })));
    await assertFails(setDoc(doc(as(ADMIN), 'followUps', 'F2'), followUp({ worker: ADA, loggedBy: ADMIN })));
  });
  test('points must be an allowed value', async () => {
    for (const points of [0, 3, 7, 85, 1000, -5, '10']) {
      await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ points })));
    }
    for (const points of [5, 15, 40, 80]) {
      await assertSucceeds(setDoc(doc(as(DAVID), 'followUps', `F-${points}`), followUp({ points })));
    }
  });
  test('outcome and team must be known values', async () => {
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ outcome: 'Number off' })));
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ team: 'Choir' })));
  });
  test('no unknown fields and no pre-synced rows', async () => {
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ hacked: true })));
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ syncedToSheet: true })));
  });
  test('follow-ups cannot be edited or deleted', async () => {
    await assertFails(updateDoc(doc(as(DAVID), 'followUps', 'F1'), { note: 'changed' }));
    await assertFails(deleteDoc(doc(as(ADMIN), 'followUps', 'F1')));
  });
  test('workers read follow-ups credited to them, including admin logs', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'followUps', 'F3'), followUp({ loggedBy: ADMIN }));
    });
    await assertSucceeds(getDoc(doc(as(DAVID), 'followUps', 'F3')));
    await assertFails(getDoc(doc(as(ADA), 'followUps', 'F3')));
  });
});
