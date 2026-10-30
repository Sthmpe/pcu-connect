import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/responsive_web_shell.dart';
import '../../../domain/repositories/i_guest_repository.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';

class LogFollowUpScreen extends StatefulWidget {
  final String guestId;

  const LogFollowUpScreen({super.key, required this.guestId});

  @override
  State<LogFollowUpScreen> createState() => _LogFollowUpScreenState();
}

class _LogFollowUpScreenState extends State<LogFollowUpScreen> {
  String _selectedOutcome = 'Reached';
  final TextEditingController _noteController = TextEditingController();

  bool _cameSunday = false;
  DateTime _sundayDate = DateTime.now();

  bool _cameWednesday = false;
  DateTime _wednesdayDate = DateTime.now();

  String _selectedTeam = 'Not yet'; // 'Not yet' | 'Workforce' | 'Evangelism'
  bool _isSubmitting = false;

  final List<String> _outcomes = [
    'Reached',
    'No answer',
    'Number off',
    'Not interested'
  ];

  final List<String> _teams = ['Not yet', 'Workforce', 'Evangelism'];

  Future<void> _pickDate(bool isSunday) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isSunday ? _sundayDate : _wednesdayDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now(), // Enforce: No future dates allowed!
    );

    if (picked != null) {
      setState(() {
        if (isSunday) {
          _sundayDate = picked;
        } else {
          _wednesdayDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final guestRepo = context.read<IGuestRepository>();
    final result = await guestRepo.logFollowUp(
      guestId: widget.guestId,
      outcome: _selectedOutcome,
      note: _noteController.text.trim(),
      attendedSunday: _cameSunday,
      sundayDate: _cameSunday ? _sundayDate : null,
      attendedWednesday: _cameWednesday,
      wednesdayDate: _cameWednesday ? _wednesdayDate : null,
      team: _selectedTeam == 'Not yet' ? '' : _selectedTeam,
    );

    setState(() => _isSubmitting = false);

    if (result.isSuccess) {
      // Trigger instant UI feedback
      Get.snackbar(
        'Follow-up Logged',
        'Guest record and points updated successfully!',
        backgroundColor: AppColors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Refresh guest list in BLoC
      if (mounted) {
        context.read<GuestsBloc>().add(const LoadGuestsEvent());
        Navigator.pop(context);
      }
    } else {
      Get.snackbar(
        'Submission Error',
        result.failure?.message ?? 'Could not save follow-up.',
        backgroundColor: AppColors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveWebShell(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            // Dark Header
            Container(
              color: AppColors.navy,
              padding: EdgeInsets.fromLTRB(16.w, 42.h, 16.w, 18.h),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFFB9C4D8), size: 18),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Log a follow-up',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                children: [
                  // Outcome Chips
                  Text('Call Outcome', style: AppTextStyles.formLabel),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: _outcomes.map((outcome) {
                      final isSelected = _selectedOutcome == outcome;
                      return InkWell(
                        onTap: () =>
                            setState(() => _selectedOutcome = outcome),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.navy : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.navy
                                  : const Color(0xFFC3CAD6),
                              width: 1.5.w,
                            ),
                          ),
                          child: Text(
                            outcome,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF3A455A),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16.h),

                  // Note Textarea
                  Text('Feedback Notes', style: AppTextStyles.formLabel),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter call summary, prayer requests, etc.',
                      hintStyle: AppTextStyles.bodyMuted,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Color(0xFFC3CAD6), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Color(0xFFC3CAD6), width: 1.5),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Sunday Attendance Toggle & Date
                  _buildAttendanceToggle(
                    title: 'Came on Sunday',
                    value: _cameSunday,
                    date: _sundayDate,
                    onChanged: (val) => setState(() => _cameSunday = val),
                    onPickDate: () => _pickDate(true),
                  ),
                  SizedBox(height: 12.h),

                  // Wednesday Attendance Toggle & Date
                  _buildAttendanceToggle(
                    title: 'Came on Wednesday',
                    value: _cameWednesday,
                    date: _wednesdayDate,
                    onChanged: (val) => setState(() => _cameWednesday = val),
                    onPickDate: () => _pickDate(false),
                  ),
                  SizedBox(height: 16.h),

                  // Joined Team Selection
                  Text('Joined a team?', style: AppTextStyles.formLabel),
                  SizedBox(height: 8.h),
                  Row(
                    children: _teams.map((t) {
                      final isSelected = _selectedTeam == t;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: InkWell(
                            onTap: () => setState(() => _selectedTeam = t),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 44.h,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.navy
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.navy
                                      : const Color(0xFFC3CAD6),
                                  width: 1.5.w,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF3A455A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Bottom Save Button
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line, width: 1)),
              ),
              child: InkWell(
                onTap: _isSubmitting ? null : _submit,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 50.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24.r,
                          height: 24.r,
                          child: const CircularProgressIndicator(
                            color: AppColors.navy,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text('Save follow-up', style: AppTextStyles.buttonGold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceToggle({
    required String title,
    required bool value,
    required DateTime date,
    required ValueChanged<bool> onChanged,
    required VoidCallback onPickDate,
  }) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC3CAD6), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.green,
              ),
            ],
          ),
          if (value) ...[
            const Divider(color: AppColors.line),
            InkWell(
              onTap: onPickDate,
              child: Row(
                children: [
                  const Icon(Icons.event, color: AppColors.muted, size: 20),
                  SizedBox(width: 8.w),
                  Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(date)}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
