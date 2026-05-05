import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/all_task_models.dart';
 
class TaskFilterBar extends StatelessWidget {
  final List<TeamModel>     teams;
  final List<EmployeeModel> employees;
  final TeamModel?     selectedTeam;
  final EmployeeModel? selectedEmployee;
  final bool isLoadingFilter;
  final ValueChanged<TeamModel?>     onTeamSelected;
  final ValueChanged<EmployeeModel?> onEmployeeSelected;
  final VoidCallback onApply;
  final VoidCallback onClear;
 
  const TaskFilterBar({
    super.key,
    required this.teams,
    required this.employees,
    required this.selectedTeam,
    required this.selectedEmployee,
    required this.isLoadingFilter,
    required this.onTeamSelected,
    required this.onEmployeeSelected,
    required this.onApply,
    required this.onClear,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Team dropdown
              Expanded(
                child: _DropdownField<TeamModel>(
                  label: 'Filter by Team',
                  hint: 'All Teams',
                  value: selectedTeam,
                  items: teams,
                  itemLabel: (t) => t.teamName,
                  onChanged: onTeamSelected,
                ),
              ),
              const SizedBox(width: 12),
              // Employee dropdown
              Expanded(
                child: isLoadingFilter
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryGreen),
                        ),
                      )
                    : _DropdownField<EmployeeModel>(
                        label: 'Select Employee *',
                        hint: 'Choose employee...',
                        value: selectedEmployee,
                        items: employees,
                        itemLabel: (e) =>
                            '${e.name} [${e.roleDisplay ?? "Employee"}]',
                        onChanged: onEmployeeSelected,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: onApply,
                  child: const Text(
                    'Apply Filter',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.borderColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onClear,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
 
          // Active filter chips
          if (selectedTeam != null || selectedEmployee != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (selectedTeam != null)
                  _FilterChip(
                    label: selectedTeam!.teamName,
                    icon: Icons.group_outlined,
                    onRemove: () => onTeamSelected(null),
                  ),
                if (selectedEmployee != null)
                  _FilterChip(
                    label: selectedEmployee!.name,
                    icon: Icons.person_outline,
                    onRemove: () => onEmployeeSelected(null),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
 
class _DropdownField<T> extends StatelessWidget {
  final String label;
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
 
  const _DropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: Text(hint,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.hintColor)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMutedDark, size: 20),
              items: [
                DropdownMenuItem<T>(
                  value: null,
                  child: Text(hint,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.hintColor)),
                ),
                ...items.map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      itemLabel(item),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
 
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onRemove;
 
  const _FilterChip(
      {required this.label, required this.icon, required this.onRemove});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }
}