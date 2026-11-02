import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_icons.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/widgets/app_controls.dart';
import 'package:workflow/presentation/common/outstanding_button.dart';

void main() {
  testWidgets('Assign guests and the outstanding icon: same size, same circle, aligned, 44 or more to tap', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var outstanding = 0, assign = 0;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: AppSizes.designSize,
      builder: (_, _) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              // As on the HOD's Guests screen.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutstandingButton(count: 3, onTap: () => outstanding++),
                  const SizedBox(width: 4),
                  AppIconButton(icon: AppIcons.addPerson, tooltip: 'Assign guests', onTap: () => assign++),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    final buttons = find.byType(AppIconButton);
    expect(buttons, findsNWidgets(2));
    final a = tester.getRect(buttons.at(0)), b = tester.getRect(buttons.at(1));
    expect(a.size, b.size, reason: 'same touch area');
    expect(a.width, greaterThanOrEqualTo(44));
    expect(a.height, greaterThanOrEqualTo(44));
    expect(a.center.dy, b.center.dy, reason: 'aligned');
    final circles = find.descendant(of: buttons, matching: find.byType(Material));
    expect(tester.getSize(circles.at(0)), tester.getSize(circles.at(1)), reason: 'same circle');
    expect((tester.widget<Material>(circles.at(0)).shape), isA<CircleBorder>());
    expect((tester.widget<Material>(circles.at(1)).shape), isA<CircleBorder>());
    // A tap near the edge of the 48px box counts, not only on the circle.
    await tester.tapAt(Offset(a.left + 2, a.bottom - 2));
    await tester.tapAt(Offset(b.right - 2, b.top + 2));
    expect([outstanding, assign], [1, 1]);
    expect(find.text('3'), findsOneWidget);
  });
}
