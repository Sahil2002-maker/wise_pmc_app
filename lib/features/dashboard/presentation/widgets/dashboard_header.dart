// lib/features/dashboard/presentation/widgets/dashboard_header.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class DashboardHeader extends StatelessWidget {
  final String userName;
  final String userRole;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.userRole,
    this.showMenuButton = false,
    this.onMenuTap,
  });

  Future<void> _logout(BuildContext context) async {
    await ApiService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'A';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showMenuButton ? 12 : 20,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEF1F8), width: 1),
        ),
      ),
      child: Row(
        children: [
          // ── Menu button (mobile) ─────────────────────────────────────
          if (showMenuButton) ...[
            GestureDetector(
              onTap: onMenuTap,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Color(0xFF4A5568),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // ── Greeting ─────────────────────────────────────────────────
          if (!showMenuButton)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_greeting()}, $userName 👋',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2340),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _formattedDate(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E9BB5),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            )
          else
            const Expanded(
              child: Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2340),
                ),
              ),
            ),

          // ── Notification bell ─────────────────────────────────────────
          _NotificationBell(),
          const SizedBox(width: 10),

          // ── Divider ───────────────────────────────────────────────────
          Container(
            width: 1,
            height: 28,
            color: const Color(0xFFE8EBF4),
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),

          // ── User info + avatar ────────────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!showMenuButton) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2340),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        userRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
              ],
              PopupMenuButton<String>(
                tooltip: 'Account',
                offset: const Offset(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.15),
                onSelected: (value) async {
                  switch (value) {
                    case 'profile':
                      _openProfile(context);
                      break;
                    case 'logout':
                      await _logout(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    height: 56,
                    value: 'header',
                    child: Row(
                      children: [
                        _AvatarWidget(letter: firstLetter, size: 36),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF1A2340),
                              ),
                            ),
                            Text(
                              userRole,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8E9BB5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'profile',
                    height: 44,
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF1FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: Color(0xFF4C6FFF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'My Profile',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'logout',
                    height: 44,
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: Color(0xFFE74C3C),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE74C3C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: _AvatarWidget(letter: firstLetter, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

// ── Avatar widget ─────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String letter;
  final double size;

  const _AvatarWidget({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF43C880), Color(0xFF2DA765)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.30),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

// ── Notification bell ─────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF4A5568),
            size: 20,
          ),
        ),
        Positioned(
          top: 8,
          right: 9,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}