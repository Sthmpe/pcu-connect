import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/constants/app_colors.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/domain/entities/insights.dart';
import 'package:workflow/presentation/worker/screens/ranking_tab.dart';

RankingEntry entry(int rank) => RankingEntry(email: 'w$rank@x.com', name: 'Worker $rank', points: 100 - rank, rank: rank);

void main() {
  test('only my own row, and only outside the top three', () {
    expect(rankRowHighlighted(entry(3), isMe: true), isFalse);
    expect(rankRowHighlighted(entry(1), isMe: true), isFalse);
    expect(rankRowHighlighted(entry(4), isMe: true), isTrue);
    expect(rankRowHighlighted(entry(9), isMe: true), isTrue);
    expect(rankRowHighlighted(entry(9), isMe: false), isFalse);
  });

  testWidgets('the highlighted row is soft gold and says You', (tester) async {
    Future<Color?> colorOf(int rank, bool isMe) async {
      await tester.pumpWidget(ScreenUtilInit(
        designSize: AppSizes.designSize,
        builder: (_, __) => MaterialApp(home: Scaffold(body: RankRow(entry: entry(rank), isMe: isMe))),
      ));
      final box = tester.widget<Container>(find.descendant(of: find.byType(RankRow), matching: find.byType(Container)).first);
      return box.color;
    }

    expect(await colorOf(5, true), AppColors.goldSoft);
    expect(find.text('You'), findsOneWidget);
    expect(await colorOf(2, true), isNull);
    expect(find.text('You'), findsOneWidget);
    expect(await colorOf(5, false), isNull);
  });
}
