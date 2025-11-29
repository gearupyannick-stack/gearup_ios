import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/club_service.dart';

class ClubCreatePage extends StatefulWidget {
  const ClubCreatePage({Key? key}) : super(key: key);

  @override
  State<ClubCreatePage> createState() => _ClubCreatePageState();
}

class _ClubCreatePageState extends State<ClubCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = true;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('User not authenticated');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final clubId = await ClubService.instance.createClub(
        name: _nameController.text,
        description: _descriptionController.text,
        isPublic: _isPublic,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('clubs.create.success'.tr()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back with the club ID
        Navigator.pop(context, clubId);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('clubs.create.error'.tr(namedArgs: {'error': error})),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('clubs.create.title'.tr()),
        backgroundColor: const Color(0xFF3D0000),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Club Name
              TextFormField(
                controller: _nameController,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: 'clubs.info.name'.tr(),
                  hintText: 'clubs.create.nameHint'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.groups),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a club name';
                  }
                  if (value.trim().length < 3) {
                    return 'Club name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLength: 200,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'clubs.info.description'.tr(),
                  hintText: 'clubs.create.descriptionHint'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Visibility Section
              Text(
                'clubs.create.visibilityLabel'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Public Option
              _buildVisibilityOption(
                isPublic: true,
                title: 'clubs.info.public'.tr(),
                description: 'clubs.create.publicDescription'.tr(),
                icon: Icons.public,
              ),
              const SizedBox(height: 12),

              // Private Option
              _buildVisibilityOption(
                isPublic: false,
                title: 'clubs.info.private'.tr(),
                description: 'clubs.create.privateDescription'.tr(),
                icon: Icons.lock,
              ),
              const SizedBox(height: 32),

              // Create Button
              ElevatedButton(
                onPressed: _isCreating ? null : _createClub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isCreating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('clubs.create.creating'.tr()),
                        ],
                      )
                    : Text(
                        'clubs.create.createButton'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption({
    required bool isPublic,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _isPublic == isPublic;

    return GestureDetector(
      onTap: () => setState(() => _isPublic = isPublic),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3D0000).withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3D0000) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF3D0000) : Colors.grey[600],
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF3D0000) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF3D0000),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
