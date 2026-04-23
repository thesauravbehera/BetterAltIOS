import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
  String? _currentPhotoUrl;  // Firebase Storage URL
  int _selectedAge = 25;
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _phoneNumber = user.phoneNumber ?? '';
      _emailController.text = user.email ?? '';
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
            if (data['profile_photo_url'] != null && data['profile_photo_url'].toString().isNotEmpty) {
              _currentPhotoUrl = data['profile_photo_url'];
            } else if (data['profile_photo_base64'] != null && data['profile_photo_base64'].toString().isNotEmpty) {
              _currentPhotoUrl = 'base64:${data['profile_photo_base64']}';
            }
            if (data['name'] != null) {
              _nameController.text = data['name'];
            }
            if (data['email'] != null && _emailController.text.isEmpty) {
              _emailController.text = data['email'];
            }
            if (data['phone_number'] != null && _phoneNumber.isEmpty) {
              _phoneNumber = data['phone_number'];
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
        final file = File(image.path);
        final fileSize = await file.length();
        debugPrint('EditProfile: Image picked, file size: $fileSize bytes');
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      // Upload new photo if picked
      if (_selectedImage != null) {
        bool photoSaved = false;
        
        // Try Firebase Storage first
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_photos')
              .child('${user.uid}.jpg');
          await storageRef.putFile(
            _selectedImage!,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          final downloadUrl = await storageRef.getDownloadURL();
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'profile_photo_url': downloadUrl,
            'profile_photo_base64': FieldValue.delete(),
          }, SetOptions(merge: true));
          if (mounted) setState(() => _currentPhotoUrl = downloadUrl);
          photoSaved = true;
          debugPrint('EditProfile: Photo saved to Storage ✅');
        } catch (storageError) {
          debugPrint('EditProfile: Storage FAILED, using base64 fallback...');
        }
        
        // Fallback: store as base64 in Firestore
        if (!photoSaved) {
          try {
            final bytes = await _selectedImage!.readAsBytes();
            final base64Str = base64Encode(bytes);
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'profile_photo_base64': base64Str,
            }, SetOptions(merge: true));
            if (mounted) setState(() => _currentPhotoUrl = 'base64:$base64Str');
            debugPrint('EditProfile: Photo saved as base64 ✅');
          } catch (b64Error) {
            debugPrint('EditProfile: Base64 also failed: $b64Error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Could not save photo'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
              );
            }
          }
        }
      }

      // Update basic fields
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'age': _selectedAge,
      }, SetOptions(merge: true));
      await user.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile updated successfully"),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return 'Not set';
    // Format: +91 62804 26194
    if (phone.startsWith('+91') && phone.length >= 13) {
      final digits = phone.substring(3);
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: CustomScrollView(
        slivers: [
          // Custom gradient header with avatar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : AppColors.canvasLight,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
            title: Text("Edit Profile", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A2E) : AppColors.canvasLight,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      // Profile Picture
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.black,
                                backgroundImage: _selectedImage != null 
                                    ? FileImage(_selectedImage!) as ImageProvider
                                    : (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                                        ? (_currentPhotoUrl!.startsWith('base64:')
                                            ? MemoryImage(base64Decode(_currentPhotoUrl!.substring(7)))
                                            : NetworkImage(_currentPhotoUrl!) as ImageProvider)
                                        : null,
                                child: (_selectedImage == null && (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty))
                                    ? const Icon(Icons.person, size: 48, color: Colors.white)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tap to change photo",
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Form content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Personal Information
                  _sectionHeader("Personal Information", Icons.person_outline_rounded, isDark),
                  const SizedBox(height: 14),
                  
                  _formCard([
                    AppTextField(
                      label: "Full Name",
                      controller: _nameController,
                      hint: "Enter your full name",
                      prefixIcon: Icons.badge_outlined,
                      isPremiumWhite: true,
                    ),
                    const SizedBox(height: 18),
                    // Age Picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.borderDark : Colors.grey.shade400, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_outlined, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary, size: 22),
                          const SizedBox(width: 12),
                          Text("Age", style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
                          const Spacer(),
                          DropdownButton<int>(
                            value: _selectedAge,
                            underline: const SizedBox(),
                            dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
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
                  ], isDark),
                  
                  const SizedBox(height: 28),
                  
                  // Section: Contact Information
                  _sectionHeader("Contact Information", Icons.contact_mail_outlined, isDark),
                  const SizedBox(height: 14),
                  
                  _formCard([
                    // Phone Number (read-only)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark.withOpacity(0.5) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.borderDark : Colors.grey.shade400, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone_outlined, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Phone Number",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatPhone(_phoneNumber),
                                  style: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Verified ✓",
                              style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Email
                    AppTextField(
                      label: "Email Address",
                      controller: _emailController,
                      hint: "Enter your email",
                      prefixIcon: Icons.email_outlined,
                      isPremiumWhite: true,
                    ),
                  ], isDark),
                  
                  const SizedBox(height: 40),
                  
                  // Save Button — Premium Style
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF2D2D44), const Color(0xFF1A1A2E)]
                              : [const Color(0xFF2D3436), const Color(0xFF1A1A2E)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1A1A2E).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveProfile,
                        icon: _isLoading 
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 22),
                        label: Text(
                          _isLoading ? "Saving..." : "Save Changes",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  /// Delete Account Button (styled like Save Changes)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD32F2F).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _deleteAccount(context),
                        icon: const Icon(Icons.delete_outline_rounded, size: 22),
                        label: const Text(
                          "Delete Account",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _formCard(List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("Are you sure you want to permanently delete your account and all data? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete user's firestore data
        await FirebaseFirestore.instance.collection("users").doc(user.uid).delete();
        // Delete user record
        await user.delete();
        // Sign out
        await FirebaseAuth.instance.signOut();
        // Pop back to login is handled by app_router / auth state listener automatically
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete account. Please log out, log back in, and try again (Security requirement).")),
        );
      }
    }
  }
}
