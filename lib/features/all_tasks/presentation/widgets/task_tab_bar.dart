import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
 
class TaskTabBar extends StatelessWidget {
  final TabController tabController;
  final List<String> tabs;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
 
  const TaskTabBar({
    super.key,
    required this.tabController,
    required this.tabs,
    required this.searchController,
    required this.onSearchChanged,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Tab bar
          TabBar(
            controller: tabController,
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textMutedDark,
            indicatorColor: AppColors.primaryGreen,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
 
          // Search bar
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.textMutedDark, size: 18),
                  hintText: 'Search tasks...',
                  hintStyle:
                      TextStyle(color: AppColors.hintColor, fontSize: 13),
                ),
              ),
            ),
          ),
          Container(height: 1, color: AppColors.borderColor),
        ],
      ),
    );
  }
}