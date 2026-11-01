import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_colors.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/domain/entities/team_member.dart';
import 'package:workflow/presentation/admin/screens/admin_team_tab.dart';

void main() {
  Future<void> row(WidgetTester tester, int outstanding) => tester.pumpWidget(ScreenUtilInit(
        designSize: AppSizes.designSize,
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: WorkerRow(
              member: const TeamMember(
                  id: 'W005', name: 'David Olanite', email: 'd@x.com', role: 'Worker', active: true, guests: 12, members: 2, points: 40),
              outstanding: outstanding,
            ),
          ),
        ),
      ));

  testWidgets('a red outstanding count when the worker has outstanding guests', (tester) async {
    await row(tester, 4);
    final rich = tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && w.textSpan != null));
    final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.text, '12 guests · 2 members');
    expect(spans.last.text, ' · 4 outstanding');
    expect(spans.last.style?.color, AppColors.redInk);
  });

  testWidgets('nothing extra when there are none', (tester) async {
    await row(tester, 0);
    expect(find.textContaining('outstanding', findRichText: true), findsNothing);
  });
}
