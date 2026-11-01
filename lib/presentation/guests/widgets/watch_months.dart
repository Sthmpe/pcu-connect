import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/guests_bloc.dart';
import '../bloc/guests_event.dart';

/// Makes sure the guest cache has [months] loaded (or live) while [child] is
/// on screen. It only asks for data; it never changes anyone's selection.
class WatchMonths extends StatefulWidget {
  final List<String> months;
  final Widget child;

  const WatchMonths({super.key, required this.months, required this.child});

  @override
  State<WatchMonths> createState() => _WatchMonthsState();
}

class _WatchMonthsState extends State<WatchMonths> {
  @override
  void initState() {
    super.initState();
    context.read<GuestsBloc>().add(WatchMonthsEvent(widget.months));
  }

  @override
  void didUpdateWidget(WatchMonths old) {
    super.didUpdateWidget(old);
    if (old.months.join(',') != widget.months.join(',')) {
      context.read<GuestsBloc>().add(WatchMonthsEvent(widget.months));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
