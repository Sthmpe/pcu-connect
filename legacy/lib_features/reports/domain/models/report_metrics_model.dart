import 'package:equatable/equatable.dart';

class ReportMetricsModel extends Equatable {
  final int totalReceived;
  final int totalContacted;
  final int totalRetained;
  final int totalConverts;
  final int totalBecameWorkers;
  final double contactRate;
  final double retentionRate;

  const ReportMetricsModel({
    required this.totalReceived,
    required this.totalContacted,
    required this.totalRetained,
    required this.totalConverts,
    required this.totalBecameWorkers,
    required this.contactRate,
    required this.retentionRate,
  });

  factory ReportMetricsModel.fromCounts({
    required int received,
    required int contacted,
    required int retained,
    required int converts,
    required int workers,
  }) {
    final contactPct = received > 0 ? (contacted / received) * 100 : 0.0;
    final retentionPct = received > 0 ? (retained / received) * 100 : 0.0;

    return ReportMetricsModel(
      totalReceived: received,
      totalContacted: contacted,
      totalRetained: retained,
      totalConverts: converts,
      totalBecameWorkers: workers,
      contactRate: double.parse(contactPct.toStringAsFixed(1)),
      retentionRate: double.parse(retentionPct.toStringAsFixed(1)),
    );
  }

  @override
  List<Object?> get props => [
    totalReceived,
    totalContacted,
    totalRetained,
    totalConverts,
    totalBecameWorkers,
    contactRate,
    retentionRate,
  ];
}
