import 'package:equatable/equatable.dart';

/// Failure categories a repository can surface to a bloc.
/// Kept generic so UI code never needs to inspect raw exceptions
/// (which could otherwise leak stack traces / query details to users).
enum FailureType {
  network,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  unknown,
}

class AppFailure extends Equatable {
  final FailureType type;
  final String message;

  const AppFailure(this.type, this.message);

  factory AppFailure.unknown([Object? error]) => AppFailure(
    FailureType.unknown,
    'Something went wrong. Please try again.',
  );

  @override
  List<Object?> get props => [type, message];
}

/// Either-style result. Repositories return this instead of throwing,
/// so blocs handle failures explicitly and UI never shows raw errors.
sealed class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;
  factory Result.failure(AppFailure failure) = Failed<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(AppFailure failure) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.data);
    if (self is Failed<T>) return failure(self.failure);
    throw StateError('Unreachable');
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failed<T> extends Result<T> {
  final AppFailure failure;
  const Failed(this.failure);
}
