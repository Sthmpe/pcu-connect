import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/guest_row.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/today_rules.dart';
import '../bloc/today_cubit.dart';
import 'today_tab.dart';

/// Every outstanding guest of the worker (since go-live, any month): the
/// current month first, then earlier months newest to oldest.
class OutstandingScreen extends StatelessWidget {
  const OutstandingScreen({super.key});

  /// Opened from the Guests screen; keeps the shell's live Today data.
  static Future<void> open(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: context.read<TodayCubit>(), child: const OutstandingScreen()),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Outstanding'),
          Expanded(
            child: BlocBuilder<TodayCubit, TodayState>(
              builder: (context, state) {
                if (state.failure != null) {
                  return ErrorState(message: state.failure!, onRetry: context.read<TodayCubit>().retry);
                }
                if (state.loading) return const SkeletonPage(rows: 4);
                final groups = outstandingByMonth(state.view.outstanding, currentMonth: MonthUtils.current());
                if (groups.isEmpty) {
                  return const Center(
                    child: EmptyState(icon: AppIcons.done, message: 'Nothing outstanding. Lovely work.'),
                  );
                }
                return PageList(
                  children: [
                    Text('Never called, and waiting more than 3 days since their visit.', style: AppTextStyles.bodyMuted),
                    for (final (month, items) in groups) ...[
                      SectionLabel('${MonthUtils.label(month)} · ${items.length}'),
                      GroupedCard(
                        dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
                        children: [
                          for (final i in items)
                            GuestRow(
                              guest: i.guest,
                              outstanding: true,
                              line: todayLine(i),
                              pill: todayPill(i.section),
                              pillTone: StatusTone.red,
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.guestDetail, arguments: GuestDetailArgs(i.guest.id)),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
