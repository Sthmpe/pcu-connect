import 'package:equatable/equatable.dart';

enum LoadStatus { initial, loading, loaded, failure }

/// State for screens that load one thing for one month.
class LoadState<T> extends Equatable {
  final LoadStatus status;
  final String month;
  final T? data;
  final String? message;

  const LoadState({
    this.status = LoadStatus.initial,
    required this.month,
    this.data,
    this.message,
  });

  bool get isLoading => status == LoadStatus.loading || status == LoadStatus.initial;

  LoadState<T> copyWith({
    LoadStatus? status,
    String? month,
    T? data,
    String? message,
  }) =>
      LoadState<T>(
        status: status ?? this.status,
        month: month ?? this.month,
        data: data ?? this.data,
        message: message,
      );

  @override
  List<Object?> get props => [status, month, data, message];
}
