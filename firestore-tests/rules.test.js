// Security rules tests. Run from firestore-tests/: npm test
// (starts the Firestore emulator for project demo-pcu, no real data involved).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs,
  serverTimestamp, writeBatch, increment,
} from 'firebase/firestore';

let env;

const ADMIN = 'boss@x.com';
const DAVID = 'david@x.com';
const ADA = 'ada@x.com';
const PAUSED = 'paused@x.com';

// Token claims for a signed-in Google user.
const as = (email, verified = true) =>
  env.authenticatedContext(email.replace(/\W/g, ''), { email, email_verified: verified }).firestore();

// Today in Africa/Lagos (UTC+1), as the rules work it out from the server clock.
const lagosDay = (offsetDays = 0) =>
  new Date(Date.now() + 3600000 + offsetDays * 86400000).toISOString().slice(0, 10);
const TODAY = lagosDay();

const followUp = (over = {}) => ({
  guestId: 'G1',
  worker: DAVID,
  loggedBy: DAVID,
  callDate: TODAY,
  month: TODAY.slice(0, 7),
  outcome: 'Reached',
  note: 'Lovely chat',
  attendedSunday: false,
  attendedWednesday: false,
  team: '',
  points: 10,
  syncedToSheet: false,
  createdAt: serverTimestamp(),
  ...over,
});

// The guest work fields the app writes with a follow-up (one batch).
const work = (followUpId, over = {}) => ({
  callStatus: 'Reached',
  membershipStatus: 'Contacted',
  followUpCount: increment(1),
  lastFeedback: 'Lovely chat',
  lastFeedbackDate: serverTimestamp(),
  updatedAt: serverTimestamp(),
  lastFollowUpId: followUpId,
  ...over,
});

/** One save as the app does it: the follow-up plus the guest's work fields. */
function save(db, id, fu = {}, guestId = 'G1', w = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'followUps', id), followUp({ guestId, ...fu }));
  batch.update(doc(db, 'guests', guestId), work(id, w));
  return batch.commit();
}

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
      name: 'Guest One', phone: '0803', gender: 'Female', month: '2026-10', assignedTo: DAVID, followUpCount: 0,
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
  test('a worker reads the gender the backend wrote, without any rule change', async () => {
    const snap = await assertSucceeds(getDoc(doc(as(DAVID), 'guests', 'G1')));
    assert.equal(snap.data().gender, 'Female');
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
  test('a worker updates work fields on their own guest, together with a follow-up', async () => {
    await assertSucceeds(save(as(DAVID), 'F2'));
  });
  test('sheet-owned fields can never be changed from the app', async () => {
    await assertFails(updateDoc(doc(as(DAVID), 'guests', 'G1'), { assignedTo: ADA }));
    await assertFails(updateDoc(doc(as(DAVID), 'guests', 'G1'), { name: 'Renamed' }));
    await assertFails(updateDoc(doc(as(ADMIN), 'guests', 'G1'), { phone: '000' }));
    await assertFails(updateDoc(doc(as(DAVID), 'guests', 'G1'), { gender: 'Male' }));
    await assertFails(updateDoc(doc(as(ADMIN), 'guests', 'G1'), { gender: 'Male' }));
  });
  test('a worker cannot touch someone else\'s guest', async () => {
    await assertFails(updateDoc(doc(as(DAVID), 'guests', 'G2'), { followUpCount: 1 }));
    await assertFails(save(as(DAVID), 'F2', { worker: ADA }, 'G2'));
    await assertFails(save(as(DAVID), 'F2', { worker: DAVID }, 'G2'));
  });
});

describe('follow-ups', () => {
  test('a worker logs for their own guest', async () => {
    await assertSucceeds(save(as(DAVID), 'F2'));
  });
  test('a follow-up on its own (without its guest update) is refused', async () => {
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp()));
    await assertFails(setDoc(doc(as(ADMIN), 'followUps', 'F3'), followUp({ loggedBy: ADMIN })));
  });
  test('a worker cannot log for another worker\'s guest', async () => {
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ guestId: 'G2', worker: ADA })));
  });
  test('a worker cannot credit someone else or pretend someone else logged it', async () => {
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ worker: ADA })));
    await assertFails(setDoc(doc(as(DAVID), 'followUps', 'F2'), followUp({ loggedBy: ADMIN })));
  });
  test('admin logs on behalf of the assigned worker', async () => {
    await assertSucceeds(save(as(ADMIN), 'F2', { loggedBy: ADMIN }));
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
      await assertSucceeds(save(as(DAVID), `F-${points}`, { points }));
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

describe('phase 2: saving from the app (one batch)', () => {
  test('a worker saves a follow-up and the guest work fields together', async () => {
    const db = as(DAVID);
    await assertSucceeds(save(db, 'F2', { attendedSunday: true, sundayDate: lagosDay(-3), points: 20 }, 'G1',
      { membershipStatus: 'Returning', sundayDates: [lagosDay(-3)], teamJoined: '' }));
    const g = (await getDoc(doc(db, 'guests', 'G1'))).data();
    if (g.followUpCount !== 1 || g.lastFollowUpId !== 'F2' || g.name !== 'Guest One') throw new Error(JSON.stringify(g));
  });
  test('a worker cannot write another worker\'s guest, even with a valid follow-up shape', async () => {
    await assertFails(save(as(ADA), 'F2', { worker: ADA, loggedBy: ADA }, 'G1'));
    await assertFails(updateDoc(doc(as(ADA), 'guests', 'G1'), work('F1')));
  });
  test('admin saves on behalf: worker credited, loggedBy is the admin, guest stays assigned', async () => {
    await assertSucceeds(save(as(ADMIN), 'F2', { worker: DAVID, loggedBy: ADMIN }));
    const g = (await getDoc(doc(as(ADMIN), 'guests', 'G1'))).data();
    if (g.assignedTo !== DAVID) throw new Error('reassigned');
    await assertSucceeds(getDoc(doc(as(DAVID), 'followUps', 'F2')));
  });
  test('admin cannot save as the worker, credit themselves, or reassign', async () => {
    await assertFails(save(as(ADMIN), 'F2', { worker: DAVID, loggedBy: DAVID }));
    await assertFails(save(as(ADMIN), 'F2', { worker: ADMIN, loggedBy: ADMIN }));
    await assertFails(save(as(ADMIN), 'F2', { loggedBy: ADMIN }, 'G1', { assignedTo: ADMIN }));
  });
  test('admin cannot log for a guest nobody is assigned to', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'guests', 'G3'), { name: 'Guest Three', assignedTo: '', followUpCount: 0 });
    });
    await assertFails(save(as(ADMIN), 'F2', { worker: '', loggedBy: ADMIN }, 'G3'));
  });
  test('guest work fields never change without a new follow-up for that guest', async () => {
    const db = as(DAVID);
    await assertFails(updateDoc(doc(db, 'guests', 'G1'), work('F1')));            // F1 already exists
    await assertFails(updateDoc(doc(db, 'guests', 'G1'), work('F-missing')));     // no follow-up in the batch
    const batch = writeBatch(db);                                                  // follow-up for another guest
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'guests', 'G4'), { name: 'Four', assignedTo: DAVID, followUpCount: 0 });
    });
    batch.set(doc(db, 'followUps', 'F2'), followUp({ guestId: 'G4' }));
    batch.update(doc(db, 'guests', 'G1'), work('F2'));
    await assertFails(batch.commit());
  });
  test('the follow-up count goes up by exactly one', async () => {
    await assertFails(save(as(DAVID), 'F2', {}, 'G1', { followUpCount: 5 }));
    await assertFails(save(as(DAVID), 'F3', {}, 'G1', { followUpCount: 0 }));
  });
  test('work field values must be known', async () => {
    await assertFails(save(as(DAVID), 'F2', {}, 'G1', { membershipStatus: 'VIP' }));
    await assertFails(save(as(DAVID), 'F3', {}, 'G1', { callStatus: 'Number off' }));
    await assertFails(save(as(DAVID), 'F4', {}, 'G1', { teamJoined: 'Choir' }));
  });
  test('attendance and call dates are never in the future', async () => {
    await assertFails(save(as(DAVID), 'F2', { attendedSunday: true, sundayDate: lagosDay(2) }));
    await assertFails(save(as(DAVID), 'F3', { attendedWednesday: true, wednesdayDate: lagosDay(1) }));
    await assertFails(save(as(DAVID), 'F4', { attendedSunday: true, sundayDate: '' }));
    await assertFails(save(as(DAVID), 'F5', { callDate: lagosDay(1), month: lagosDay(1).slice(0, 7) }));
    await assertFails(save(as(DAVID), 'F6', { month: '1999-01' }));
    await assertSucceeds(save(as(DAVID), 'F7', { attendedWednesday: true, wednesdayDate: lagosDay(-1), points: 15 }));
  });
  test('times come from the server clock', async () => {
    await assertFails(save(as(DAVID), 'F2', { createdAt: new Date() }));
    await assertFails(save(as(DAVID), 'F3', {}, 'G1', { updatedAt: new Date() }));
  });
  test('sheet-owned fields stay out of an app save', async () => {
    await assertFails(save(as(DAVID), 'F2', {}, 'G1', { name: 'Renamed' }));
    await assertFails(save(as(DAVID), 'F3', {}, 'G1', { phone: '000' }));
    await assertFails(save(as(ADMIN), 'F4', { loggedBy: ADMIN }, 'G1', { serviceDate: '2026-01-01' }));
    await assertFails(save(as(DAVID), 'F5', {}, 'G1', { gender: 'Male' }));
  });
});

describe('push tokens (users/{email}/tokens/{token})', () => {
  const TOKEN = 'fcm-token_abc:123-XYZ';
  const tokenDoc = (over = {}) => ({ token: TOKEN, platform: 'web', userAgent: 'Mozilla/5.0', createdAt: serverTimestamp(), lastSeenAt: serverTimestamp(), ...over });
  const tokenRef = (db, email = DAVID, id = TOKEN) => doc(db, 'users', email, 'tokens', id);

  test('a worker saves, refreshes, reads and deletes their own device token', async () => {
    const db = as(DAVID);
    await assertSucceeds(setDoc(tokenRef(db), tokenDoc()));
    await assertSucceeds(updateDoc(tokenRef(db), { lastSeenAt: serverTimestamp(), userAgent: 'Chrome' }));
    await assertSucceeds(getDoc(tokenRef(db)));
    await assertSucceeds(deleteDoc(tokenRef(db)));
  });
  test('nobody else reads or writes a person\'s tokens, not even an admin', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await setDoc(tokenRef(ctx.firestore()), tokenDoc({ createdAt: new Date(), lastSeenAt: new Date() })); });
    await assertFails(getDoc(tokenRef(as(ADA))));
    await assertFails(getDoc(tokenRef(as(ADMIN))));
    await assertFails(setDoc(tokenRef(as(ADA), DAVID, 'other'), tokenDoc({ token: 'other' })));
    await assertFails(deleteDoc(tokenRef(as(ADMIN))));
    await assertFails(getDocs(collection(as(ADMIN), 'users', DAVID, 'tokens')));
  });
  test('the token document must match its id, with server times and known fields', async () => {
    const db = as(DAVID);
    await assertFails(setDoc(tokenRef(db), tokenDoc({ token: 'different' })));
    await assertFails(setDoc(tokenRef(db), tokenDoc({ platform: 'ios' })));
    await assertFails(setDoc(tokenRef(db), tokenDoc({ createdAt: new Date() })));
    await assertFails(setDoc(tokenRef(db), tokenDoc({ admin: true })));
    await assertFails(setDoc(tokenRef(db), tokenDoc({ userAgent: 'x'.repeat(301) })));
  });
  test('an update only moves lastSeenAt and userAgent', async () => {
    const db = as(DAVID);
    await assertSucceeds(setDoc(tokenRef(db), tokenDoc()));
    await assertFails(updateDoc(tokenRef(db), { platform: 'android', lastSeenAt: serverTimestamp() }));
    await assertFails(updateDoc(tokenRef(db), { lastSeenAt: new Date() }));
  });
  test('inactive or unverified people cannot save tokens', async () => {
    await assertFails(setDoc(tokenRef(as(PAUSED), PAUSED), tokenDoc()));
    await assertFails(setDoc(tokenRef(as(DAVID, false)), tokenDoc()));
  });
});

describe('notifications (users/{email}/notifications)', () => {
  const ref = (db, email = DAVID, id = 'N1') => doc(db, 'users', email, 'notifications', id);
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(ref(ctx.firestore()), { title: 'New guest for you', body: 'Ada Obi', tag: 'guest-G1', read: false, createdAt: new Date() });
    });
  });
  test('a worker reads their own list and the unread count query', async () => {
    await assertSucceeds(getDoc(ref(as(DAVID))));
    await assertSucceeds(getDocs(query(collection(as(DAVID), 'users', DAVID, 'notifications'), where('read', '==', false))));
  });
  test('nobody else reads them, not even an admin', async () => {
    await assertFails(getDoc(ref(as(ADA))));
    await assertFails(getDoc(ref(as(ADMIN))));
    await assertFails(getDocs(collection(as(ADMIN), 'users', DAVID, 'notifications')));
  });
  test('marking as read is the only change, with the server time', async () => {
    await assertSucceeds(updateDoc(ref(as(DAVID)), { read: true, readAt: serverTimestamp() }));
    await assertFails(updateDoc(ref(as(DAVID)), { title: 'Changed' }));
    await assertFails(updateDoc(ref(as(DAVID)), { read: false, readAt: serverTimestamp() }));
    await assertFails(updateDoc(ref(as(DAVID)), { read: true, readAt: new Date() }));
    await assertFails(updateDoc(ref(as(ADA)), { read: true, readAt: serverTimestamp() }));
  });
  test('the app never creates or deletes notifications', async () => {
    await assertFails(setDoc(ref(as(DAVID), DAVID, 'N2'), { title: 'Fake', read: false, createdAt: serverTimestamp() }));
    await assertFails(deleteDoc(ref(as(DAVID))));
    await assertFails(setDoc(ref(as(ADMIN), DAVID, 'N3'), { title: 'Fake', read: false }));
  });
});

describe('leaderboard entries (rankings/{month}/entries/{email})', () => {
  const MONTH = TODAY.slice(0, 7);
  const entry = (db, email = DAVID, month = MONTH) => doc(db, 'rankings', month, 'entries', email);
  // One save with the leaderboard move, as the app does it.
  function saveRanked(db, id, fu = {}, rank = {}, guestId = 'G1') {
    const batch = writeBatch(db);
    const f = followUp({ guestId, ...fu });
    batch.set(doc(db, 'followUps', id), f);
    batch.update(doc(db, 'guests', guestId), work(id));
    batch.set(entry(db, rank.email || f.worker, rank.month || MONTH), {
      email: rank.email || f.worker, name: rank.name ?? 'David', points: increment(rank.points ?? f.points),
      lastFollowUpId: rank.lastFollowUpId || id, updatedAt: serverTimestamp(), ...(rank.extra || {}),
    }, { merge: true });
    return batch.commit();
  }

  test('a save moves the worker\'s entry by exactly the follow-up\'s points; everyone can read it', async () => {
    await assertSucceeds(saveRanked(as(DAVID), 'F2', { points: 15 }));
    await assertSucceeds(saveRanked(as(DAVID), 'F3', { points: 5 }));
    const e = (await getDoc(entry(as(ADA)))).data();
    if (e.points !== 20) throw new Error('points ' + e.points);
  });
  test('admin on behalf moves the worker\'s entry', async () => {
    await assertSucceeds(saveRanked(as(ADMIN), 'F2', { worker: DAVID, loggedBy: ADMIN, points: 10 }, { name: 'David' }));
  });
  test('wrong points, another worker, another month or a replayed follow-up are refused', async () => {
    await assertFails(saveRanked(as(DAVID), 'F2', { points: 10 }, { points: 50 }));
    await assertFails(saveRanked(as(DAVID), 'F3', { points: 10 }, { email: ADA }));
    await assertFails(saveRanked(as(DAVID), 'F4', { points: 10 }, { month: '2020-01' }));
    await assertFails(setDoc(entry(as(DAVID)), { email: DAVID, name: 'David', points: 999, lastFollowUpId: 'F1', updatedAt: serverTimestamp() }));
    await assertFails(saveRanked(as(DAVID), 'F5', { points: 10 }, { extra: { hacked: true } }));
  });
  test('admins are never ranked', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'guests', 'G9'), { name: 'Admin guest', assignedTo: ADMIN, followUpCount: 0 });
    });
    await assertFails(saveRanked(as(ADMIN), 'F2', { guestId: 'G9', worker: ADMIN, loggedBy: ADMIN, points: 10 }, { name: 'Boss' }, 'G9'));
  });
  test('entries are never deleted from the app', async () => {
    await assertSucceeds(saveRanked(as(DAVID), 'F2', { points: 10 }));
    await assertFails(deleteDoc(entry(as(DAVID))));
    await assertFails(deleteDoc(entry(as(ADMIN))));
  });
});

describe('security review: guest status and dates follow the business rules', () => {
  const sundays = [lagosDay(-21), lagosDay(-14), lagosDay(-7)];
  test('Member needs at least 3 Sundays on record and the server time as memberSince', async () => {
    await assertFails(save(as(DAVID), 'F2', {}, 'G1', { membershipStatus: 'Member', memberSince: serverTimestamp() }));
    await assertFails(save(as(DAVID), 'F3', {}, 'G1', { membershipStatus: 'Member', sundayDates: sundays }));
    await assertFails(save(as(DAVID), 'F4', {}, 'G1', { membershipStatus: 'Member', sundayDates: sundays, memberSince: new Date() }));
    await assertSucceeds(save(as(DAVID), 'F5', { points: 45 }, 'G1', { membershipStatus: 'Member', sundayDates: sundays, memberSince: serverTimestamp() }));
  });
  test('Member and Not interested stay', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'guests', 'G1'), { membershipStatus: 'Member', memberSince: new Date() });
      await updateDoc(doc(ctx.firestore(), 'guests', 'G2'), { membershipStatus: 'Not interested' });
    });
    await assertFails(save(as(DAVID), 'F2', {}, 'G1', { membershipStatus: 'Contacted' }));
    await assertSucceeds(save(as(DAVID), 'F3', {}, 'G1', { membershipStatus: 'Member' }));
    await assertFails(save(as(ADA), 'F4', { worker: ADA, loggedBy: ADA, guestId: 'G2' }, 'G2', { membershipStatus: 'Returning' }));
  });
  test('attendance dates only grow; first call and feedback times are the server time, set once', async () => {
    await assertSucceeds(save(as(DAVID), 'F2', {}, 'G1', { sundayDates: [lagosDay(-7)], firstCallAt: serverTimestamp() }));
    await assertFails(save(as(DAVID), 'F3', {}, 'G1', { sundayDates: [] }));
    await assertFails(save(as(DAVID), 'F4', {}, 'G1', { firstCallAt: serverTimestamp() }));
    await assertFails(save(as(DAVID), 'F5', {}, 'G1', { lastFeedbackDate: new Date() }));
    await assertFails(save(as(DAVID), 'F6', {}, 'G1', { sundayDates: Array.from({ length: 400 }, (_, i) => String(i)) }));
  });
});

describe('message templates (config/messageTemplates)', () => {
  const PAUSED_ADMIN = 'old.boss@x.com';
  const ref = (db) => doc(db, 'config', 'messageTemplates');
  const templates = (over = {}) => ({
    thanks: 'Dear {title} {name}, thank you. {worker}, COZA Ilorin',
    missedCall: 'Dear {title} {name}, I tried calling you.',
    checkIn: 'Dear {title} {name}, since {service}.',
    updatedAt: serverTimestamp(),
    updatedBy: ADMIN,
    ...over,
  });

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', PAUSED_ADMIN), { name: 'Old Boss', email: PAUSED_ADMIN, role: 'admin', active: false });
    });
  });

  test('every active user reads them; signed-out and inactive people do not', async () => {
    await assertSucceeds(getDoc(ref(as(DAVID))));
    await assertSucceeds(getDoc(ref(as(ADMIN))));
    await assertFails(getDoc(ref(as(PAUSED))));
    await assertFails(getDoc(ref(env.unauthenticatedContext().firestore())));
  });
  test('an active admin saves all three, then edits them', async () => {
    await assertSucceeds(setDoc(ref(as(ADMIN)), templates()));
    await assertSucceeds(setDoc(ref(as(ADMIN)), templates({ thanks: 'New words' })));
    const snap = await getDoc(ref(as(DAVID)));
    assert.equal(snap.data().thanks, 'New words');
  });
  test('workers and inactive admins cannot write', async () => {
    await assertFails(setDoc(ref(as(DAVID)), templates({ updatedBy: DAVID })));
    await assertFails(setDoc(ref(as(PAUSED_ADMIN)), templates({ updatedBy: PAUSED_ADMIN })));
  });
  test('the shape is checked: all three, words in each, at most 1000 characters, server time, own email', async () => {
    const db = as(ADMIN);
    const missing = templates(); delete missing.checkIn;
    await assertFails(setDoc(ref(db), missing));
    await assertFails(setDoc(ref(db), templates({ thanks: '' })));
    await assertFails(setDoc(ref(db), templates({ thanks: 'x'.repeat(1001) })));
    await assertSucceeds(setDoc(ref(db), templates({ thanks: 'x'.repeat(1000) })));
    await assertFails(setDoc(ref(db), templates({ extra: 'no' })));
    await assertFails(setDoc(ref(db), templates({ updatedAt: new Date() })));
    await assertFails(setDoc(ref(db), templates({ updatedBy: DAVID })));
  });
  test('nobody deletes them', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await setDoc(ref(ctx.firestore()), templates({ updatedAt: new Date() })); });
    await assertFails(deleteDoc(ref(as(ADMIN))));
  });
});
