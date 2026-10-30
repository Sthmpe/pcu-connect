import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_terminology.dart';
import 'terminology_repository.dart';

/// App-wide, loaded once per signed-in session (see app.dart: triggered
/// off AuthBloc reaching AuthAuthenticated). Falls back to PCU Workflow
/// defaults immediately so screens never show a blank label while the
/// organization doc loads - `state` is always a valid AppTerminology,
/// never null.
class TerminologyCubit extends Cubit<AppTerminology> {
  final TerminologyRepository _repository;

  TerminologyCubit({TerminologyRepository? repository})
    : _repository = repository ?? TerminologyRepository(),
      super(AppTerminology.defaults);

  Future<void> loadForOrganization(String organizationId) async {
    try {
      final terminology = await _repository.fetchForOrganization(
        organizationId,
      );
      emit(terminology);
    } catch (_) {
      // Terminology is cosmetic, not security- or data-critical - silently
      // keep whatever labels were already showing rather than blocking
      // the UI on a label-fetch failure.
    }
  }
}
