import '../errors/failures.dart';

/// Clean Result monad for safe functional error handling
abstract class ApiResult<T> {
  const ApiResult();

  const factory ApiResult.success(T data) = SuccessResult<T>;
  const factory ApiResult.failure(Failure failure) = FailureResult<T>;

  bool get isSuccess => this is SuccessResult<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get data => isSuccess ? (this as SuccessResult<T>).value : null;
  Failure? get failure => isFailure ? (this as FailureResult<T>).error : null;
}

class SuccessResult<T> implements ApiResult<T> {
  final T value;
  const SuccessResult(this.value);

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  T? get data => value;

  @override
  Failure? get failure => null;
}

class FailureResult<T> implements ApiResult<T> {
  final Failure error;
  const FailureResult(this.error);

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get data => null;

  @override
  Failure? get failure => error;
}
