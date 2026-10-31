import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_result.dart';
import '../../core/utils/month_utils.dart';
import '../../domain/entities/insights.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/i_team_repository.dart';
import 'load_state.dart';

/// Loads one month of data and keeps the last good result on failure.
abstract class _MonthCubit<T> extends Cubit<LoadState<T>> {
  _MonthCubit() : super(LoadState<T>(month: MonthUtils.current()));

  Future<ApiResult<T>> fetch(String month);

  Future<void> load([String? month]) async {
    final m = month ?? state.month;
    final keep = m == state.month ? state.data : null;
    emit(LoadState<T>(status: LoadStatus.loading, month: m, data: keep));
    final result = await fetch(m);
    if (isClosed) return;
    if (result.isSuccess) {
      emit(LoadState<T>(status: LoadStatus.loaded, month: m, data: result.data));
    } else {
      emit(LoadState<T>(
        status: LoadStatus.failure,
        month: m,
        data: keep,
        message: result.failure?.message,
      ));
    }
  }

  /// Loads once; later calls are ignored until [load] is called directly.
  void ensureLoaded() {
    if (state.status == LoadStatus.initial) load();
  }

  void reset() => emit(LoadState<T>(month: MonthUtils.current()));
}

class RankingCubit extends _MonthCubit<Ranking> {
  final ITeamRepository _repo;

  RankingCubit(this._repo);

  @override
  Future<ApiResult<Ranking>> fetch(String month) => _repo.fetchRanking(month: month);
}

class DashboardCubit extends _MonthCubit<DashboardSummary> {
  final ITeamRepository _repo;

  DashboardCubit(this._repo);

  @override
  Future<ApiResult<DashboardSummary>> fetch(String month) =>
      _repo.fetchDashboard(month: month);
}

class TeamCubit extends _MonthCubit<List<TeamMember>> {
  final ITeamRepository _repo;

  TeamCubit(this._repo);

  @override
  Future<ApiResult<List<TeamMember>>> fetch(String month) =>
      _repo.fetchTeam(month: month);

  List<TeamMember> get members => state.data ?? const [];

  TeamMember? byId(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Active workers ranked by members then contacts, then admins, then inactive.
  List<TeamMember> get ranked {
    int group(TeamMember m) => !m.active ? 2 : (m.isAdmin ? 1 : 0);
    final list = [...members];
    list.sort((a, b) {
      final g = group(a).compareTo(group(b));
      if (g != 0) return g;
      final m = b.members.compareTo(a.members);
      if (m != 0) return m;
      return b.contacted.compareTo(a.contacted);
    });
    return list;
  }

  Future<ApiResult<TeamMember>> add({
    required String name,
    required String email,
    required String phone,
    required String role,
    required bool active,
  }) async {
    final result = await _repo.saveWorker(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      role: role,
      active: active,
    );
    if (result.isSuccess && !isClosed) {
      emit(state.copyWith(data: [...members, result.data!]));
    }
    return result;
  }

  Future<ApiResult<TeamMember>> setActive(String id, bool active) async {
    final before = members;
    // Optimistic: flip now, roll back if the server refuses.
    emit(state.copyWith(
        data: [for (final m in before) m.id == id ? m.copyWith(active: active) : m]));
    final result = await _repo.setWorkerActive(id: id, active: active);
    if (isClosed) return result;
    if (result.isSuccess) {
      emit(state.copyWith(
          data: [for (final m in members) m.id == id ? result.data! : m]));
    } else {
      emit(state.copyWith(data: before));
    }
    return result;
  }
}
