import 'package:equatable/equatable.dart';

import '../../domain/models/membership_model.dart';

abstract class AccessState extends Equatable {
  const AccessState();

  @override
  List<Object?> get props => [];
}

class AccessLoading extends AccessState {
  const AccessLoading();
}

class AccessReady extends AccessState {
  final MembershipModel membership;

  const AccessReady(this.membership);

  bool can(String capability) => membership.can(capability);

  @override
  List<Object?> get props => [membership];
}

/// No membership doc found for this unit - the user has no access here.
/// Distinct from a load error so the UI can show "not assigned" instead
/// of a generic failure.
class AccessDenied extends AccessState {
  const AccessDenied();
}

class AccessFailure extends AccessState {
  final String message;

  const AccessFailure(this.message);

  @override
  List<Object?> get props => [message];
}
