import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/utils/contact_launcher.dart';
import 'package:workflow/core/widgets/guest_row.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/presentation/guests/bloc/guests_state.dart';

GuestEntity guest(String id, String name, String phone) => GuestEntity(
      id: id,
      name: name,
      phone: phone,
      status: 'New guest',
      daysSinceVisit: 0,
      serviceDate: '2026-10-28',
      callCount: 0,
      sundayAttendance: 0,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: '',
      lastFeedbackDate: '',
      followUpCount: 0,
      month: '2026-10',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final all = [
    guest('1', 'Ada Obi', '0803 123 4567'),
    guest('2', 'Tunde Bello', '+234 816 555 0000'),
    guest('3', 'Grace Adaeze', '07011112222'),
  ];

  group('GuestFilters.search', () {
    test('an empty or blank query keeps everyone', () {
      expect(GuestFilters.search(all, ''), all);
      expect(GuestFilters.search(all, '   '), all);
    });

    test('matches part of a name, ignoring case', () {
      expect(GuestFilters.search(all, 'ADA').map((g) => g.id), ['1', '3']);
      expect(GuestFilters.search(all, 'bello').map((g) => g.id), ['2']);
    });

    test('matches phone digits, ignoring spaces and symbols', () {
      expect(GuestFilters.search(all, '1234567').map((g) => g.id), ['1']);
      expect(GuestFilters.search(all, '816 555').map((g) => g.id), ['2']);
      expect(GuestFilters.search(all, '+234 816').map((g) => g.id), ['2']);
    });

    test('no match gives an empty list', () {
      expect(GuestFilters.search(all, 'zzz'), isEmpty);
      expect(GuestFilters.search(all, '999999'), isEmpty);
    });
  });

  group('Long-press copies the number', () {
    String? copied;

    setUp(() {
      copied = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('a worker row copies on long-press and shows a snackbar', (tester) async {
      await tester.pumpWidget(ScreenUtilInit(
        designSize: AppSizes.designSize,
        builder: (_, __) => GetMaterialApp(
          home: Scaffold(body: GuestRow(guest: all.first, onTap: () {})),
        ),
      ));
      await tester.longPress(find.byType(GuestRow));
      await tester.pump();
      expect(copied, '0803 123 4567');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Number copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('an empty number copies nothing', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      await ContactLauncher.copyPhone(guest('9', 'No Phone', '  '));
      expect(copied, isNull);
    });
  });
}
