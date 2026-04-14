import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/widgets/widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
  String? _currentPhotoBase64;
  int _selectedAge = 25;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _loadUserData(user.uid);
    }
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            if (data['profile_photo_base64'] != null) {
              _currentPhotoBase64 = data['profile_photo_base64'];
            }
            if (data['name'] != null) {
              _nameController.text = data['name'];
            }
            if (data['age'] != null) {
              _selectedAge = data['age'] is String ? int.tryParse(data['age']) ?? 25 : data['age'];
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 300, maxHeight: 300);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Image picker error: \$e");
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      // Upload new photo if picked
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final base64String = base64Encode(bytes);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profile_photo_base64': base64String,
        });
      }

      // Update basic fields
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'age': _selectedAge,
      });

      // Update Firebase Auth profile displayName
      await user.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
        Navigator.pop(context, true); // return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Edit Profile", style: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
        iconTheme: IconThemeData(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            
            // Profile Picture Customizer
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    backgroundImage: _selectedImage != null 
                        ? FileImage(_selectedImage!) as ImageProvider
                        : (_currentPhotoBase64 != null ? MemoryImage(base64Decode(_currentPhotoBase64!)) : null),
                    child: (_selectedImage == null && _currentPhotoBase64 == null)
                        ? Icon(Icons.person, size: 50, color: isDark ? Colors.white54 : Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Update Photo (Optional)",
              style: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
            ),
            
            const SizedBox(height: 40),
            
            AppTextField(
              label: "Full Name",
              controller: _nameController,
              hint: "Enter your name",
              prefixIcon: Icons.person_outline_rounded,
            ),
            
            const SizedBox(height: 20),
            
            // Age Scroller
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text("Age", style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _selectedAge,
                    underline: const SizedBox(),
                    dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                    items: List.generate(82, (index) => index + 18).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text("$value", style: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() => _selectedAge = newValue);
                      }
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 50), // Add spacer area
            
            AppButton(
              label: "Save Changes",
              isLoading: _isLoading,
              onPressed: _saveProfile,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

