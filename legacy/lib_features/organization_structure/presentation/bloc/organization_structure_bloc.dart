import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/i_organization_structure_repository.dart';
import 'organization_structure_event.dart';
import 'organization_structure_state.dart';

class OrganizationStructureBloc
    extends Bloc<OrganizationStructureEvent, OrganizationStructureState> {
  final IOrganizationStructureRepository _repository;

  OrganizationStructureBloc({
    required IOrganizationStructureRepository repository,
  }) : _repository = repository,
       super(const OrganizationStructureState()) {
    on<LoadOrganizationStructure>(_onLoad);
    on<SaveOrganization>(_onSaveOrganization);
    on<CreateLocation>(_onCreateLocation);
    on<UpdateLocation>(_onUpdateLocation);
    on<ArchiveLocation>(_onArchiveLocation);
    on<CreateUnit>(_onCreateUnit);
    on<UpdateUnit>(_onUpdateUnit);
    on<ArchiveUnit>(_onArchiveUnit);
  }

  Future<void> _onLoad(
    LoadOrganizationStructure event,
    Emitter<OrganizationStructureState> emit,
  ) async {
    emit(
      state.copyWith(
        status: OrganizationStructureStatus.loading,
        organizationId: event.organizationId,
        clearError: true,
      ),
    );
    try {
      final organizationFuture = _repository.fetchOrganization(
        event.organizationId,
      );
      final locationsFuture = _repository.fetchLocations(event.organizationId);
      final unitsFuture = _repository.fetchUnits(event.organizationId);
      final organization = await organizationFuture;
      final locations = await locationsFuture;
      final units = await unitsFuture;
      emit(
        OrganizationStructureState(
          status: OrganizationStructureStatus.ready,
          organizationId: event.organizationId,
          organization: organization,
          locations: locations,
          units: units,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: OrganizationStructureStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _reload(Emitter<OrganizationStructureState> emit) async {
    final organizationFuture = _repository.fetchOrganization(
      state.organizationId,
    );
    final locationsFuture = _repository.fetchLocations(state.organizationId);
    final unitsFuture = _repository.fetchUnits(state.organizationId);
    final organization = await organizationFuture;
    final locations = await locationsFuture;
    final units = await unitsFuture;
    emit(
      OrganizationStructureState(
        status: OrganizationStructureStatus.ready,
        organizationId: state.organizationId,
        organization: organization,
        locations: locations,
        units: units,
      ),
    );
  }

  Future<void> _mutate(
    Future<void> Function() action,
    Emitter<OrganizationStructureState> emit,
  ) async {
    if (state.status == OrganizationStructureStatus.saving) return;
    emit(
      state.copyWith(
        status: OrganizationStructureStatus.saving,
        clearError: true,
      ),
    );
    try {
      await action();
      await _reload(emit);
    } catch (error) {
      emit(
        state.copyWith(
          status: OrganizationStructureStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onSaveOrganization(
    SaveOrganization event,
    Emitter<OrganizationStructureState> emit,
  ) => _mutate(
    () => _repository.saveOrganization(
      organizationId: state.organizationId,
      name: event.name,
      code: event.code,
    ),
    emit,
  );

  Future<void> _onCreateLocation(
    CreateLocation event,
    Emitter<OrganizationStructureState> emit,
  ) => _mutate(() async {
    await _repository.createLocation(
      organizationId: state.organizationId,
      name: event.name,
      code: event.code,
    );
  }, emit);

  Future<void> _onUpdateLocation(
    UpdateLocation event,
    Emitter<OrganizationStructureState> emit,
  ) => _mutate(
    () => _repository.updateLocation(
      locationId: event.locationId,
      name: event.name,
      code: event.code,
    ),
    emit,
  );

  Future<void> _onArchiveLocation(
    ArchiveLocation event,
    Emitter<OrganizationStructureState> emit,
  ) => _mutate(() => _repository.archiveLocation(event.locationId), emit);

  Future<void> _onCreateUnit(
    CreateUnit event,
    Emitter<OrganizationStructureState> emit,
  ) => _mutate(() async {
    await _repository.createUnit(
      organizationId: state.organizationId,
      locationId: event.locationId,
      name: event.name,
      code: event.code,
    );
  }, emit);

  Future<void> _onUpdateUnit(
    UpdateUnit event,
    Emitter<OrganizationStructureState> emit,
  ) => _mutate(
    () => _repository.updateUnit(
      unitId: event.unitId,
      name: event.name,
      code: event.code,
    ),
    emit,
  );

  Future<void> _onArchiveUnit(
    ArchiveUnit event,
    Emitter<OrganizationStructureState> emit,
  ) => _mutate(() => _repository.archiveUnit(event.unitId), emit);
}
