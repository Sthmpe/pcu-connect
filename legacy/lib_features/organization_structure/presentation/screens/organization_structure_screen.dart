import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/terminology/terminology_cubit.dart';
import '../../domain/models/location_model.dart';
import '../../domain/models/unit_model.dart';
import '../bloc/organization_structure_bloc.dart';
import '../bloc/organization_structure_event.dart';
import '../bloc/organization_structure_state.dart';

class OrganizationStructureScreen extends StatefulWidget {
  final String organizationId;

  const OrganizationStructureScreen({super.key, required this.organizationId});

  @override
  State<OrganizationStructureScreen> createState() =>
      _OrganizationStructureScreenState();
}

class _OrganizationStructureScreenState
    extends State<OrganizationStructureScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OrganizationStructureBloc>().add(
      LoadOrganizationStructure(widget.organizationId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final terminology = context.select(
      (TerminologyCubit cubit) => (
        organization: cubit.state.organization,
        location: cubit.state.location,
        unit: cubit.state.unit,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.manageStructure)),
      body: BlocConsumer<OrganizationStructureBloc, OrganizationStructureState>(
        listener: (context, state) {
          if (state.status == OrganizationStructureStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == OrganizationStructureStatus.initial ||
              state.status == OrganizationStructureStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeLocations = state.activeLocations;
          final activeUnits = state.activeUnits;
          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.all(AppSizes.p16),
                children: [
                  _SectionHeader(
                    title: terminology.organization,
                    actionLabel: AppStrings.editAction,
                    onAction: () => _editOrganization(context, state),
                  ),
                  _OrganizationCard(
                    name: state.organization?.name ?? terminology.organization,
                    code: state.organization?.code ?? '',
                  ),
                  SizedBox(height: AppSizes.p24),
                  _SectionHeader(
                    title: terminology.location,
                    actionLabel: AppStrings.addAction,
                    onAction: () => _createLocation(context),
                  ),
                  if (activeLocations.isEmpty)
                    const _EmptyCard(message: AppStrings.noLocations)
                  else
                    ...activeLocations.map(
                      (location) => _LocationTile(
                        location: location,
                        onEdit: () => _editLocation(context, location),
                        onArchive: () => context
                            .read<OrganizationStructureBloc>()
                            .add(ArchiveLocation(location.id)),
                      ),
                    ),
                  SizedBox(height: AppSizes.p24),
                  _SectionHeader(
                    title: terminology.unit,
                    actionLabel: AppStrings.addAction,
                    onAction: activeLocations.isEmpty
                        ? null
                        : () => _createUnit(context, activeLocations),
                  ),
                  if (activeUnits.isEmpty)
                    const _EmptyCard(message: AppStrings.noUnits)
                  else
                    ...activeUnits.map(
                      (unit) => _UnitTile(
                        unit: unit,
                        locationName: _locationName(
                          activeLocations,
                          unit.locationId,
                        ),
                        onEdit: () => _editUnit(context, unit),
                        onArchive: () => context
                            .read<OrganizationStructureBloc>()
                            .add(ArchiveUnit(unit.id)),
                        onManageAccess: () => Navigator.of(context).pushNamed(
                          AppRoutes.delegation,
                          arguments: DelegationRouteArguments(
                            unitId: unit.id,
                            unitName: unit.name,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (state.status == OrganizationStructureStatus.saving)
                const Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.modalBarrier,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _locationName(List<LocationModel> locations, String locationId) {
    for (final location in locations) {
      if (location.id == locationId) return location.name;
    }
    return '';
  }

  Future<void> _editOrganization(
    BuildContext context,
    OrganizationStructureState state,
  ) async {
    final value = await _showNameCodeDialog(
      context,
      title: AppStrings.organizationDetails,
      initialName: state.organization?.name ?? '',
      initialCode: state.organization?.code ?? '',
    );
    if (value != null && context.mounted) {
      context.read<OrganizationStructureBloc>().add(
        SaveOrganization(name: value.name, code: value.code),
      );
    }
  }

  Future<void> _createLocation(BuildContext context) async {
    final label = context.read<TerminologyCubit>().state.location;
    final value = await _showNameCodeDialog(
      context,
      title: '${AppStrings.addAction} $label',
    );
    if (value != null && context.mounted) {
      context.read<OrganizationStructureBloc>().add(
        CreateLocation(name: value.name, code: value.code),
      );
    }
  }

  Future<void> _editLocation(
    BuildContext context,
    LocationModel location,
  ) async {
    final value = await _showNameCodeDialog(
      context,
      title:
          '${AppStrings.editAction} ${context.read<TerminologyCubit>().state.location}',
      initialName: location.name,
      initialCode: location.code,
    );
    if (value != null && context.mounted) {
      context.read<OrganizationStructureBloc>().add(
        UpdateLocation(
          locationId: location.id,
          name: value.name,
          code: value.code,
        ),
      );
    }
  }

  Future<void> _createUnit(
    BuildContext context,
    List<LocationModel> locations,
  ) async {
    final value = await _showUnitDialog(
      context,
      locations: locations,
      title:
          '${AppStrings.addAction} ${context.read<TerminologyCubit>().state.unit}',
    );
    if (value != null && context.mounted) {
      context.read<OrganizationStructureBloc>().add(
        CreateUnit(
          locationId: value.locationId,
          name: value.name,
          code: value.code,
        ),
      );
    }
  }

  Future<void> _editUnit(BuildContext context, UnitModel unit) async {
    final value = await _showNameCodeDialog(
      context,
      title:
          '${AppStrings.editAction} ${context.read<TerminologyCubit>().state.unit}',
      initialName: unit.name,
      initialCode: unit.code,
    );
    if (value != null && context.mounted) {
      context.read<OrganizationStructureBloc>().add(
        UpdateUnit(unitId: unit.id, name: value.name, code: value.code),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.titleLarge)),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final String name;
  final String code;

  const _OrganizationCard({required this.name, required this.code});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_tree_outlined),
        title: Text(name),
        subtitle: code.isEmpty ? null : Text(code),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _LocationTile({
    required this.location,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(location.name),
        subtitle: Text(location.code),
        trailing: _ItemActions(onEdit: onEdit, onArchive: onArchive),
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  final UnitModel unit;
  final String locationName;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onManageAccess;

  const _UnitTile({
    required this.unit,
    required this.locationName,
    required this.onEdit,
    required this.onArchive,
    required this.onManageAccess,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.groups_outlined),
        title: Text(unit.name),
        subtitle: Text(
          [
            unit.code,
            locationName,
          ].where((value) => value.isNotEmpty).join(AppStrings.listSeparator),
        ),
        trailing: _ItemActions(
          onEdit: onEdit,
          onArchive: onArchive,
          onManageAccess: onManageAccess,
        ),
      ),
    );
  }
}

class _ItemActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback? onManageAccess;

  const _ItemActions({
    required this.onEdit,
    required this.onArchive,
    this.onManageAccess,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onManageAccess != null)
          IconButton(
            tooltip: AppStrings.manageAccessTooltip,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: onManageAccess,
          ),
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
        IconButton(
          icon: const Icon(Icons.archive_outlined),
          onPressed: onArchive,
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.p16),
        child: Text(message, style: AppTextStyles.bodyMedium),
      ),
    );
  }
}

class _NameCodeValue {
  final String name;
  final String code;

  const _NameCodeValue(this.name, this.code);
}

class _UnitValue extends _NameCodeValue {
  final String locationId;

  const _UnitValue(super.name, super.code, this.locationId);
}

Future<_NameCodeValue?> _showNameCodeDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  String initialCode = '',
}) async {
  final nameController = TextEditingController(text: initialName);
  final codeController = TextEditingController(text: initialCode);
  final result = await showDialog<_NameCodeValue>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: AppStrings.nameLabel),
          ),
          SizedBox(height: AppSizes.p12),
          TextField(
            controller: codeController,
            decoration: const InputDecoration(labelText: AppStrings.codeLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text(AppStrings.cancelAction),
        ),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            final code = codeController.text.trim();
            if (name.isNotEmpty && code.isNotEmpty) {
              Navigator.pop(dialogContext, _NameCodeValue(name, code));
            }
          },
          child: const Text(AppStrings.saveAction),
        ),
      ],
    ),
  );
  nameController.dispose();
  codeController.dispose();
  return result;
}

Future<_UnitValue?> _showUnitDialog(
  BuildContext context, {
  required List<LocationModel> locations,
  required String title,
}) async {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  var selectedLocationId = locations.first.id;
  final result = await showDialog<_UnitValue>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedLocationId,
              items: locations
                  .map(
                    (location) => DropdownMenuItem(
                      value: location.id,
                      child: Text(location.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null)
                  setDialogState(() => selectedLocationId = value);
              },
            ),
            SizedBox(height: AppSizes.p12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.nameLabel,
              ),
            ),
            SizedBox(height: AppSizes.p12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: AppStrings.codeLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancelAction),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final code = codeController.text.trim();
              if (name.isNotEmpty && code.isNotEmpty) {
                Navigator.pop(
                  dialogContext,
                  _UnitValue(name, code, selectedLocationId),
                );
              }
            },
            child: const Text(AppStrings.saveAction),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  codeController.dispose();
  return result;
}
