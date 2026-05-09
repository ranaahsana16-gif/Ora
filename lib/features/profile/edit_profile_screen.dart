import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameC;
  bool _loading = false;
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).valueOrNull;
    _nameC = TextEditingController(text: profile?.fullName);
    _avatarUrl = profile?.avatarUrl;
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _loading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${ref.read(currentUserProvider)?.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      final supabase = Supabase.instance.client;
      await supabase.storage.from('avatars').uploadBinary(fileName, bytes);
      final url = supabase.storage.from('avatars').getPublicUrl(fileName);

      setState(() {
        _avatarUrl = url;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) context.showOraSnackBar('Failed to upload image: $e', isError: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      final profile = ref.read(profileProvider).valueOrNull;
      
      final newName = _nameC.text.trim();

      await AuthService.updateUser(
        fullName: newName != profile?.fullName ? newName : null,
        avatarUrl: _avatarUrl != profile?.avatarUrl ? _avatarUrl : null,
      );

      if (mounted) {
        context.showOraSnackBar('Profile updated successfully!');

        ref.read(profileProvider.notifier).refresh();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OraTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: OraTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Avatar section
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: OraTheme.cardLight,
                            image: _avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(color: OraTheme.primaryOrange.withValues(alpha: 0.2), width: 4),
                          ),
                          child: _avatarUrl == null
                              ? const Icon(Icons.person, size: 60, color: OraTheme.textMuted)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: OraTheme.primaryOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  OraInput(
                    controller: _nameC,
                    label: 'Full Name',
                    prefixIcon: Icons.person_outline,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 40),

                  OraButton(
                    label: 'Save Changes',
                    onPressed: _save,
                    isLoading: _loading,
                    icon: Icons.check,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
