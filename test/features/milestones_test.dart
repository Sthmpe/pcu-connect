import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/core/storage/member_celebrations.dart';
import 'package:workflow/core/widgets/confetti.dart';
import 'package:workflow/data/firestore/firestore_mappers.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/milestones.dart';

GuestEntity g(String id, String status, String memberSince) => GuestEntity(
      id: id,
      name: 'Guest $id',
      phone: '',
      status: status,
      daysSinceVisit: 0,
      serviceDate: '2026-10-04',
      callCount: 1,
      sundayAttendance: 0,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: '',
      lastFeedbackDate: '',
      followUpCount: 1,
      month: '2026-10',
      memberSince: memberSince,
    );

void main() {
  group('Becoming a member', () {
    test('only the save that changes the status to Member', () {
      expect(Milestones.becameMember(before: 'Returning', after: 'Member'), isTrue);
      expect(Milestones.becameMember(before: 'Member', after: 'Member'), isFalse);
      expect(Milestones.becameMember(before: 'Contacted', after: 'Returning'), isFalse);
      expect(Milestones.becameMember(before: '', after: 'Member'), isTrue);
    });

    test('remembered once per guest on this device', () async {
      SharedPreferences.setMockInitialValues({});
      final c = MemberCelebrations(await SharedPreferences.getInstance());
      expect(await c.claim('G1'), isTrue);
      expect(await c.claim('G1'), isFalse);
      expect(await c.claim('G2'), isTrue);
      // After a restart.
      final again = MemberCelebrations(await SharedPreferences.getInstance());
      expect(await again.claim('G1'), isFalse);
    });
  });

  group('The monthly card', () {
    test('counts members whose member day is in the month', () {
      final guests = [
        g('a', 'Member', '2026-11-08'),
        g('b', 'Member', '2026-11-29'),
        g('c', 'Member', '2026-10-25'),
        g('d', 'Returning', ''),
        g('e', 'Member', ''),
      ];
      expect(Milestones.membersHelped(guests, '2026-11'), 2);
      expect(Milestones.membersHelped(guests, '2026-10'), 1);
    });

    test('the words', () {
      expect(Milestones.helpedLine(1), 'You helped 1 guest become a member');
      expect(Milestones.helpedLine(3), 'You helped 3 guests become members');
    });

    test('member day from Firestore is the Lagos day', () {
      final guest = FirestoreMappers.guest('G1', {
        'membershipStatus': 'Member',
        // 23:30 UTC on 30 November is 1 December in Lagos.
        'memberSince': Timestamp.fromDate(DateTime.utc(2026, 11, 30, 23, 30)),
      });
      expect(guest.memberSince, '2026-12-01');
      expect(FirestoreMappers.guest('G2', {}).memberSince, '');
      expect(GuestEntity.fromJson({'id': 'G3', 'membershipDate': '2026-11-08'}).memberSince, '2026-11-08');
    });
  });

  group('Gold confetti', () {
    testWidgets('plays over the screen, then removes itself', (tester) async {
      final key = GlobalKey<OverlayState>();
      await tester.pumpWidget(MaterialApp(home: Overlay(key: key, initialEntries: [OverlayEntry(builder: (_) => const SizedBox())])));
      showGoldConfetti(key.currentState!, duration: const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(GoldConfetti), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byType(GoldConfetti), findsNothing);
    });

    testWidgets('nothing when the device asks for less motion', (tester) async {
      final key = GlobalKey<OverlayState>();
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Overlay(key: key, initialEntries: [OverlayEntry(builder: (_) => const SizedBox())])),
      ));
      showGoldConfetti(key.currentState!);
      await tester.pump();
      expect(find.byType(GoldConfetti), findsNothing);
    });
  });
}
