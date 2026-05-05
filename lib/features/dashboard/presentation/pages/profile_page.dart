import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = true;
  bool isSavingProfile = false;
  bool isSavingPassword = false;

  String profilePhotoUrl = '';
  String selectedTheme = 'light-layout';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      setState(() => isLoading = true);

      final data = await ApiService.fetchProfile();

      if (!mounted) return;

      nameController.text = data['name']?.toString() ?? '';
      emailController.text = data['email']?.toString() ?? '';
      profilePhotoUrl = data['profile_photo_url']?.toString() ?? '';
      selectedTheme = data['theme']?.toString().isNotEmpty == true
          ? data['theme'].toString()
          : 'light-layout';

      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.requiredRed,
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> saveProfile() async {
    try {
      setState(() => isSavingProfile = true);

      final message = await ApiService.updateProfile(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.requiredRed,
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSavingProfile = false);
      }
    }
  }

  Future<void> savePassword() async {
    if (newPasswordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.requiredRed,
          content: Text(
            'Password confirmation does not match.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    try {
      setState(() => isSavingPassword = true);

      final message = await ApiService.updateProfilePassword(
        currentPassword: currentPasswordController.text.trim(),
        newPassword: newPasswordController.text.trim(),
        confirmPassword: confirmPasswordController.text.trim(),
      );

      if (!mounted) return;

      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.requiredRed,
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSavingPassword = false);
      }
    }
  }

  Future<void> saveTheme(String value) async {
    try {
      setState(() => selectedTheme = value);

      final message = await ApiService.updateThemeMode(themeMode: value);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.requiredRed,
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Widget sectionCard({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primaryGreen),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: AppColors.textDark),
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                sectionCard(
                  title: 'Profile Information',
                  description:
                      'Update your account profile information and email address.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFFEDEFF7),
                          backgroundImage: profilePhotoUrl.isNotEmpty
                              ? NetworkImage(profilePhotoUrl)
                              : null,
                          child: profilePhotoUrl.isEmpty
                              ? Text(
                                  nameController.text.isNotEmpty
                                      ? nameController.text[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    color: Color(0xFF7A8CC7),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 24,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Name'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: inputDecoration('Enter name'),
                      ),
                      const SizedBox(height: 14),
                      const Text('Email'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailController,
                        decoration: inputDecoration('Enter email'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: isSavingProfile ? null : saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: isSavingProfile
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                sectionCard(
                  title: 'Update Password',
                  description:
                      'Ensure your account is using a long, random password to stay secure.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Password'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: currentPasswordController,
                        obscureText: true,
                        decoration: inputDecoration('Current password'),
                      ),
                      const SizedBox(height: 14),
                      const Text('New Password'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: inputDecoration('New password'),
                      ),
                      const SizedBox(height: 14),
                      const Text('Confirm Password'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: inputDecoration('Confirm password'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: isSavingPassword ? null : savePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: isSavingPassword
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                sectionCard(
                  title: 'Change Theme Option',
                  description: 'Change application theme mode.',
                  child: DropdownButtonFormField<String>(
                    value: selectedTheme,
                    decoration: inputDecoration('Select theme'),
                    items: const [
                      DropdownMenuItem(
                        value: 'dark-layout',
                        child: Text('Dark Mode'),
                      ),
                      DropdownMenuItem(
                        value: 'light-layout',
                        child: Text('Light Mode'),
                      ),
                      DropdownMenuItem(
                        value: 'semi-dark-layout',
                        child: Text('Semi Dark Mode'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        saveTheme(value);
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}