import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/terminology/app_terminology.dart';
import '../../../../core/terminology/terminology_cubit.dart';
import '../../domain/models/capability.dart';
import '../../domain/models/delegation_member_model.dart';
import '../../domain/models/permission_preset.dart';
import '../bloc/delegation_bloc.dart';
import '../bloc/delegation_event.dart';
import '../bloc/delegation_state.dart';

class DelegationScreen extends StatefulWidget {
  final String unitId;
  final String unitName;

  const DelegationScreen({
    super.key,
    required this.unitId,
    required this.unitName,
  });

  @override
  State<DelegationScreen> createState() => _DelegationScreenState();
}

class _DelegationScreenState extends State<DelegationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<DelegationBloc>().add(
      LoadDelegationMembers(unitId: widget.unitId, unitName: widget.unitName),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terminology = context.watch<TerminologyCubit>().state;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.manageAccess)),
      body: BlocConsumer<DelegationBloc, DelegationState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            previous.successMessage != current.successMessage,
        listener: (context, state) {
          final message = state.errorMessage ?? state.successMessage;
          if (message == null) return;
          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..removeCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: state.errorMessage == null
                    ? AppColors.success
                    : AppColors.danger,
              ),
            );
        },
        builder: (context, state) {
          if (state.status == DelegationStatus.loading &&
              state.members.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == DelegationStatus.failure &&
              state.members.isEmpty) {
            return _LoadFailure(
              message: state.errorMessage ?? AppStrings.genericError,
              onRetry: () => context.read<DelegationBloc>().add(
                LoadDelegationMembers(
                  unitId: widget.unitId,
                  unitName: widget.unitName,
                ),
              ),
            );
          }

          final members = _filteredMembers(state.members);
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  context.read<DelegationBloc>().add(
                    const RefreshDelegationMembers(),
                  );
                  await context.read<DelegationBloc>().stream.firstWhere(
                    (next) => !next.isBusy,
                  );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(AppSizes.p16),
                  children: [
                    Text(widget.unitName, style: AppTextStyles.headlineMedium),
                    SizedBox(height: AppSizes.p4),
                    Text(
                      AppStrings.accessManagementSubtitle,
                      style: AppTextStyles.bodyMedium,
                    ),
                    SizedBox(height: AppSizes.p16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        labelText: AppStrings.searchTeam,
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    SizedBox(height: AppSizes.p16),
                    if (members.isEmpty)
                      _EmptyState(
                        message: state.members.isEmpty
                            ? AppStrings.noTeamMembers
                            : AppStrings.noMatchingTeamMembers,
                      )
                    else
                      ...members.map(
                        (member) => Padding(
                          padding: EdgeInsets.only(bottom: AppSizes.p12),
                          child: _MemberCard(
                            member: member,
                            terminology: terminology,
                            onGrant: () => _openEditor(
                              context,
                              state,
                              member,
                              terminology,
                            ),
                            onRestore: () => _confirmRestore(context, member),
                          ),
                        ),
                      ),
                    if (state.hasMore)
                      Center(
                        child: TextButton(
                          onPressed:
                              state.status == DelegationStatus.loadingMore
                              ? null
                              : () => context.read<DelegationBloc>().add(
                                  const LoadMoreDelegationMembers(),
                                ),
                          child: state.status == DelegationStatus.loadingMore
                              ? SizedBox.square(
                                  dimension: AppSizes.iconMd,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(AppStrings.loadMoreAction),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.status == DelegationStatus.submitting)
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

  List<DelegationMemberModel> _filteredMembers(
    List<DelegationMemberModel> members,
  ) {
    if (_query.isEmpty) return members;
    return members
        .where(
          (member) =>
              member.displayName.toLowerCase().contains(_query) ||
              member.permissionPreset.toLowerCase().contains(_query),
        )
        .toList(growable: false);
  }

  Future<void> _openEditor(
    BuildContext context,
    DelegationState state,
    DelegationMemberModel member,
    AppTerminology terminology,
  ) async {
    final request = await showModalBottomSheet<_GrantAccessRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DelegationEditorSheet(
        member: member,
        delegablePermissions: state.delegablePermissions,
        managerLabel: terminology.unitManager,
      ),
    );
    if (request == null || !context.mounted) return;
    context.read<DelegationBloc>().add(
      GrantDelegatedAccess(
        recipientUserId: member.userId,
        permissionPreset: request.preset.wireValue,
        permissions: request.permissions,
        reason: request.reason,
      ),
    );
  }

  Future<void> _confirmRestore(
    BuildContext context,
    DelegationMemberModel member,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.restoreAccessTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppStrings.restoreAccessMessage),
            SizedBox(height: AppSizes.p16),
            TextField(
              controller: reasonController,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: AppStrings.reasonOptional,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.restoreAccess),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || !context.mounted) return;
    context.read<DelegationBloc>().add(
      RevokeDelegatedAccess(
        membershipId: member.membershipId,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final DelegationMemberModel member;
  final AppTerminology terminology;
  final VoidCallback onGrant;
  final VoidCallback onRestore;

  const _MemberCard({
    required this.member,
    required this.terminology,
    required this.onGrant,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final initial = member.displayName.trim().isEmpty
        ? '?'
        : member.displayName.trim()[0].toUpperCase();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.p16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(initial)),
                SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.displayName, style: AppTextStyles.titleLarge),
                      SizedBox(height: AppSizes.p4),
                      Text(
                        _roleLabel(member.baseRole, terminology),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (member.isDelegated) ...[
              SizedBox(height: AppSizes.p12),
              Text(
                _presetLabel(member.permissionPreset, terminology.unitManager),
                style: AppTextStyles.labelLarge,
              ),
              SizedBox(height: AppSizes.p8),
              Wrap(
                spacing: AppSizes.p8,
                runSpacing: AppSizes.p4,
                children: member.permissions
                    .map(
                      (permission) => Chip(
                        label: Text(AppStrings.capabilityLabel(permission)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (member.canManage) ...[
              SizedBox(height: AppSizes.p12),
              Wrap(
                spacing: AppSizes.p8,
                runSpacing: AppSizes.p8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onGrant,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: Text(
                      member.isDelegated
                          ? AppStrings.editAccess
                          : AppStrings.appointAssistant,
                    ),
                  ),
                  if (member.isDelegated)
                    TextButton.icon(
                      onPressed: onRestore,
                      icon: const Icon(Icons.settings_backup_restore),
                      label: const Text(AppStrings.restoreAccess),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _roleLabel(BaseRole role, AppTerminology terminology) {
    switch (role) {
      case BaseRole.organizationOwner:
        return terminology.organizationOwner;
      case BaseRole.unitManager:
        return terminology.unitManager;
      case BaseRole.delegate:
        return 'Assistant';
      case BaseRole.operator:
        return terminology.operatorLabel;
      case BaseRole.viewer:
        return 'Viewer';
    }
  }
}

class _DelegationEditorSheet extends StatefulWidget {
  final DelegationMemberModel member;
  final Set<String> delegablePermissions;
  final String managerLabel;

  const _DelegationEditorSheet({
    required this.member,
    required this.delegablePermissions,
    required this.managerLabel,
  });

  @override
  State<_DelegationEditorSheet> createState() => _DelegationEditorSheetState();
}

class _DelegationEditorSheetState extends State<_DelegationEditorSheet> {
  final TextEditingController _reasonController = TextEditingController();
  late final List<PermissionPreset> _availablePresets;
  late PermissionPreset _preset;
  late Set<String> _permissions;
  bool _showPermissionError = false;

  @override
  void initState() {
    super.initState();
    _availablePresets = PermissionPreset.values
        .where(
          (preset) => preset.isAvailableWithin(widget.delegablePermissions),
        )
        .toList(growable: false);
    final currentPreset = PermissionPreset.fromWireValue(
      widget.member.permissionPreset,
    );
    _preset =
        widget.member.isDelegated && _availablePresets.contains(currentPreset)
        ? currentPreset
        : _availablePresets.firstWhere(
            (preset) => preset == PermissionPreset.assignmentOfficer,
            orElse: () => PermissionPreset.custom,
          );
    _permissions = widget.member.isDelegated
        ? widget.member.permissions
              .where(widget.delegablePermissions.contains)
              .toSet()
        : _preset.resolvePermissions(widget.delegablePermissions).toSet();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedPermissions = widget.delegablePermissions.toList()..sort();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p16,
        AppSizes.p16,
        MediaQuery.viewInsetsOf(context).bottom + AppSizes.p16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.member.isDelegated
                  ? AppStrings.editAccess
                  : AppStrings.appointAssistant,
              style: AppTextStyles.headlineMedium,
            ),
            SizedBox(height: AppSizes.p4),
            Text(widget.member.displayName, style: AppTextStyles.bodyMedium),
            SizedBox(height: AppSizes.p16),
            DropdownButtonFormField<PermissionPreset>(
              initialValue: _preset,
              decoration: const InputDecoration(
                labelText: AppStrings.chooseAccessPreset,
              ),
              items: _availablePresets
                  .map(
                    (preset) => DropdownMenuItem(
                      value: preset,
                      child: Text(_presetDisplayLabel(preset)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (preset) {
                if (preset == null) return;
                setState(() {
                  _preset = preset;
                  _showPermissionError = false;
                  if (preset != PermissionPreset.custom) {
                    _permissions = preset
                        .resolvePermissions(widget.delegablePermissions)
                        .toSet();
                  }
                });
              },
            ),
            SizedBox(height: AppSizes.p16),
            Text(
              _preset == PermissionPreset.custom
                  ? AppStrings.customPermissions
                  : AppStrings.permissionsLabel,
              style: AppTextStyles.titleMedium,
            ),
            SizedBox(height: AppSizes.p8),
            ...sortedPermissions.map(
              (permission) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _permissions.contains(permission),
                title: Text(AppStrings.capabilityLabel(permission)),
                onChanged: _preset == PermissionPreset.custom
                    ? (selected) => setState(() {
                        _showPermissionError = false;
                        if (selected == true) {
                          _permissions.add(permission);
                        } else {
                          _permissions.remove(permission);
                        }
                      })
                    : null,
              ),
            ),
            if (_showPermissionError)
              Text(
                AppStrings.selectPermissionNotice,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            SizedBox(height: AppSizes.p12),
            TextField(
              controller: _reasonController,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: AppStrings.reasonOptional,
              ),
            ),
            SizedBox(height: AppSizes.p16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(
                  widget.member.isDelegated
                      ? AppStrings.updateAccess
                      : AppStrings.grantAccess,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _presetDisplayLabel(PermissionPreset preset) {
    if (preset == PermissionPreset.deputyManager) {
      return 'Deputy ${widget.managerLabel}';
    }
    return preset.label;
  }

  void _submit() {
    if (_permissions.isEmpty) {
      setState(() => _showPermissionError = true);
      return;
    }
    final reason = _reasonController.text.trim();
    Navigator.pop(
      context,
      _GrantAccessRequest(
        preset: _preset,
        permissions: Set.unmodifiable(_permissions),
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }
}

class _GrantAccessRequest {
  final PermissionPreset preset;
  final Set<String> permissions;
  final String? reason;

  const _GrantAccessRequest({
    required this.preset,
    required this.permissions,
    this.reason,
  });
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.p32),
      child: Center(child: Text(message, style: AppTextStyles.bodyMedium)),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            SizedBox(height: AppSizes.p12),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: AppSizes.p16),
            FilledButton(
              onPressed: onRetry,
              child: const Text(AppStrings.retryAction),
            ),
          ],
        ),
      ),
    );
  }
}

String _presetLabel(String wireValue, String managerLabel) {
  final preset = PermissionPreset.fromWireValue(wireValue);
  return preset == PermissionPreset.deputyManager
      ? 'Deputy $managerLabel'
      : preset.label;
}
