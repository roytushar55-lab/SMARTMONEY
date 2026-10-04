import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme_mode.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/login_demo_widgets.dart';
import '../../../auth/data/services/token_storage_service.dart';
import '../../data/models/profile_response.dart';
import '../../data/services/profile_api_service.dart';
import '../../../legal/data/legal_documents.dart';
import '../../../legal/presentation/screens/legal_document_screen.dart';
import '../../../shell/presentation/screens/main_shell.dart';
import 'delete_account_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _profileApiService = ProfileApiService();
  final _tokenStorageService = const TokenStorageService();
  final _imagePicker = ImagePicker();

  ProfileResponse? _profile;
  bool _isLoading = true;
  bool _isUploadingProfilePhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _profileApiService.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await _profileApiService.getProfile();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (e.isUnauthorized) {
        _promptSignIn(e.message);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to load profile')));
    }
  }

  Future<bool?> _showTextEntrySheet({
    required String title,
    required String hintText,
    required IconData icon,
    required String submitLabel,
    required Future<String?> Function(String value, String? extra) onSubmit,
    String initialValue = '',
    String? extraHintText,
    bool obscure = false,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TextEntrySheet(
        title: title,
        hintText: hintText,
        icon: icon,
        submitLabel: submitLabel,
        initialValue: initialValue,
        extraHintText: extraHintText,
        obscure: obscure,
        capitalization: capitalization,
        onSubmit: onSubmit,
      ),
    );
  }

  Future<void> _editName() async {
    final saved = await _showTextEntrySheet(
      title: 'Edit name',
      hintText: 'Full name',
      icon: Icons.badge_outlined,
      submitLabel: 'Save',
      initialValue: _profile?.fullName ?? '',
      capitalization: TextCapitalization.words,
      onSubmit: (value, _) async {
        final name = value.trim();

        if (name.isEmpty) {
          return 'Name is required';
        }

        try {
          final profile = await _profileApiService.updateName(name);
          if (mounted) {
            setState(() {
              _profile = profile;
            });
          }
          return null;
        } catch (_) {
          return 'Unable to update name';
        }
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name updated')));
    }
  }

  Future<void> _changePassword() async {
    final saved = await _showTextEntrySheet(
      title: 'Change password',
      hintText: 'New password',
      extraHintText: 'Current password',
      icon: Icons.lock_outline,
      submitLabel: 'Update password',
      obscure: true,
      onSubmit: (value, current) async {
        if (current == null || current.isEmpty) {
          return 'Enter your current password';
        }

        final problem = _passwordProblem(value);

        if (problem != null) {
          return problem;
        }

        try {
          await _profileApiService.changePassword(
            currentPassword: current,
            newPassword: value,
          );
          return null;
        } on ApiException catch (e) {
          return e.message;
        } catch (_) {
          return 'Unable to update password';
        }
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated')));
    }
  }

  /// Same rules the signup screen enforces.
  String? _passwordProblem(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain a lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain a number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must contain a special character';
    }
    return null;
  }

  void _openLegalDocument(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocumentScreen(document: document)),
    );
  }

  void _openDeleteAccount() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DeleteAccountScreen()));
  }

  Future<void> _pickProfilePhoto() async {
    if (_isUploadingProfilePhoto) {
      return;
    }

    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );

      if (photo == null || !mounted) {
        return;
      }

      setState(() {
        _isUploadingProfilePhoto = true;
      });

      final updatedProfile = await _profileApiService.uploadProfilePhoto(
        bytes: await photo.readAsBytes(),
        fileName: photo.name,
        contentType: _profilePhotoContentType(photo.name, photo.mimeType),
      );

      if (!mounted) return;

      setState(() {
        _profile = updatedProfile;
        _isUploadingProfilePhoto = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isUploadingProfilePhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile photo')),
      );
    }
  }

  String _profilePhotoContentType(String fileName, String? mimeType) {
    if (mimeType != null && mimeType.trim().isNotEmpty) {
      return mimeType;
    }

    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/jpeg';
  }

  Future<void> _logout() async {
    await _tokenStorageService.clearTokens();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, RouteNames.login, (_) => false);
  }

  /// The session is unrecoverable (revoked or expired refresh token) — tokens
  /// are already cleared by [ProfileApiService], so this only needs to offer
  /// a way back to Login rather than leaving a broken screen with no path
  /// forward.
  void _promptSignIn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Sign in',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.login,
            (_) => false,
          ),
        ),
      ),
    );
  }

  void _showMvpMessage(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label will be available soon')));
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'SM';
    }

    return parts
        .map((part) => part[0])
        .join()
        .substring(0, parts.length > 1 ? 2 : 1)
        .toUpperCase();
  }

  String _profileImageUrl(String value) {
    final imageUrl = value.trim();

    if (imageUrl.isEmpty) {
      return '';
    }

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    return '${_profileApiService.baseUrl}$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final colors = SmColors.of(context);

    return Scaffold(
      body: LoginDemoBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: colors.primary),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopNavigation(),
                          const SizedBox(height: 14),
                          _buildHeader(profile),
                          const SizedBox(height: 16),
                          _buildAccountSection(profile),
                          const SizedBox(height: 20),
                          _buildPreferencesSection(),
                          const SizedBox(height: 20),
                          _buildSupportSection(),
                          const SizedBox(height: 24),
                          _buildSessionActions(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTopNavigation() {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () {
            // This screen is reached by being pushed on top of the shell, so
            // popping is what actually reveals it again — switching the shell's
            // tab would only change what sits underneath this route. Popping
            // also returns to whichever tab the user came from.
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
              return;
            }
            // Hosted as the shell's profile tab: nothing to pop, so switch tabs.
            MainShell.shellKey.currentState?.goToTab(ShellTab.home);
          },
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to dashboard',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.74),
            foregroundColor: SmColors.of(context).primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Profile',
            style: TextStyle(
              color: SmColors.of(context).textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ProfileResponse? profile) {
    final colors = SmColors.of(context);
    final fullName = profile?.fullName ?? 'Profile';
    final email = profile?.email ?? '';
    final profilePhotoUrl = _profileImageUrl(profile?.profileImageUrl ?? '');
    final status = (profile?.status.isNotEmpty ?? false)
        ? profile!.status
        : 'Active';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryHover],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 480;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProfileAvatar(
                initials: _initials(fullName),
                imageUrl: profilePhotoUrl,
                size: isCompact ? 70 : 82,
                onPickPhoto: _pickProfilePhoto,
                isUploading: _isUploadingProfilePhoto,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 22 : 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          label: status,
                          icon: Icons.verified_user_outlined,
                        ),
                        if (profile?.isEmailVerified ?? false)
                          const _StatusPill(
                            label: 'Verified',
                            icon: Icons.check_circle_outline_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountSection(ProfileResponse? profile) {
    return _Section(
      label: 'Account',
      children: [
        _SettingsRow(
          icon: Icons.person_outline,
          title: profile?.fullName ?? '',
          subtitle: 'Full name',
          trailing: Text(
            'Edit',
            style: TextStyle(
              color: SmColors.of(context).primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          onTap: _editName,
        ),
        _SettingsRow(
          icon: Icons.email_outlined,
          title: profile?.email ?? '',
          subtitle: 'Email address',
        ),
        _SettingsRow(
          icon: Icons.phone_outlined,
          title: profile?.phoneNumber ?? '',
          subtitle: 'Phone number',
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return _Section(
      label: 'Preferences and security',
      children: [
        _SettingsRow(
          icon: Icons.lock_outline,
          title: 'Change password',
          onTap: _changePassword,
        ),
        ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (context, _) {
            final colors = SmColors.of(context);
            final isDark = ThemeController.instance.mode == AppThemeMode.dark;

            return _SettingsRow(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              title: 'Dark mode',
              subtitle: isDark ? 'On' : 'Off',
              trailing: Switch(
                value: isDark,
                activeTrackColor: colors.primary,
                onChanged: (value) {
                  ThemeController.instance.setMode(
                    value ? AppThemeMode.dark : AppThemeMode.light,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return _Section(
      label: 'Support and legal',
      children: [
        _SettingsRow(
          icon: Icons.support_agent_rounded,
          title: 'Help and support',
          onTap: () => _showMvpMessage('Help and support'),
        ),
        _SettingsRow(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          onTap: () => _openLegalDocument(LegalDocuments.terms),
        ),
        _SettingsRow(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () => _openLegalDocument(LegalDocuments.privacy),
        ),
      ],
    );
  }

  Widget _buildSessionActions() {
    final danger = SmColors.of(context).danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _logout,
          style: OutlinedButton.styleFrom(
            foregroundColor: danger,
            side: BorderSide(color: danger.withValues(alpha: 0.42)),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text(
            'Log out',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: TextButton(
            onPressed: _openDeleteAccount,
            style: TextButton.styleFrom(foregroundColor: danger),
            child: const Text(
              'Delete account',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled group of [_SettingsRow]s inside one card.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final rows = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: colors.border));
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        LoginDemoGlassCard(
          borderRadius: 20,
          // Blur disabled: these cards live inside the scroll view.
          enableBlur: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// One row of a [_Section]: icon, title, optional subtitle, and an optional
/// trailing widget. Tappable rows (those with [onTap]) get a chevron unless a
/// [trailing] widget is supplied.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final displayTitle = title.isEmpty ? 'Not available' : title;

    final trailingWidget =
        trailing ??
        (onTap != null
            ? Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
                size: 22,
              )
            : null);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: 8),
              trailingWidget,
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with a single text field, used for the name and password
/// edits. [onSubmit] returns an error message to show inline, or null when
/// the change was saved (the sheet then closes with `true`).
class _TextEntrySheet extends StatefulWidget {
  const _TextEntrySheet({
    required this.title,
    required this.hintText,
    required this.icon,
    required this.submitLabel,
    required this.onSubmit,
    this.initialValue = '',
    this.extraHintText,
    this.obscure = false,
    this.capitalization = TextCapitalization.none,
  });

  final String title;
  final String hintText;
  final IconData icon;
  final String submitLabel;
  final String initialValue;

  /// When set, a "current value" field is shown above the main one and its
  /// text is passed to [onSubmit] as `extra` (used for the current password).
  final String? extraHintText;
  final bool obscure;
  final TextCapitalization capitalization;
  final Future<String?> Function(String value, String? extra) onSubmit;

  @override
  State<_TextEntrySheet> createState() => _TextEntrySheetState();
}

class _TextEntrySheetState extends State<_TextEntrySheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  final _extraController = TextEditingController();

  late bool _hidden = widget.obscure;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _extraController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final error = await widget.onSubmit(
      _controller.text,
      widget.extraHintText == null ? null : _extraController.text,
    );

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (widget.extraHintText != null) ...[
            TextField(
              controller: _extraController,
              autofocus: true,
              obscureText: _hidden,
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: widget.extraHintText,
                prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: widget.extraHintText == null,
            obscureText: _hidden,
            enabled: !_isSaving,
            textCapitalization: widget.capitalization,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(widget.icon, color: colors.primary),
              suffixIcon: widget.obscure
                  ? IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: colors.textMuted,
                      ),
                    )
                  : null,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                color: colors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          LoginDemoGradientButton(
            label: widget.submitLabel,
            icon: Icons.check_rounded,
            isLoading: _isSaving,
            height: 48,
            onPressed: _isSaving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.imageUrl,
    required this.size,
    required this.onPickPhoto,
    required this.isUploading,
  });

  final String initials;
  final String imageUrl;
  final double size;
  final VoidCallback onPickPhoto;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final hasImage = imageUrl.trim().isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.58),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: hasImage
                  ? Image.network(
                      imageUrl,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _InitialsAvatarLabel(
                          initials: initials,
                          fontSize: size < 76 ? 24 : 28,
                        );
                      },
                    )
                  : _InitialsAvatarLabel(
                      initials: initials,
                      fontSize: size < 76 ? 24 : 28,
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Tooltip(
              message: 'Add profile photo',
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkResponse(
                  onTap: isUploading ? null : onPickPhoto,
                  radius: 18,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isUploading
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          )
                        : Icon(
                            Icons.photo_camera_outlined,
                            color: colors.primary,
                            size: 15,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatarLabel extends StatelessWidget {
  const _InitialsAvatarLabel({required this.initials, required this.fontSize});

  final String initials;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
