import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/id_verification.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/user_avatar.dart';

/// Admin-only review queue for ID verification.
///
/// Drawer exposes the entry only for allow-listed admin emails; we
/// re-check on entry so a hand-typed route can't bypass the gate.
/// Reviewer notes are optional.
class IdVerificationReviewsScreen extends StatefulWidget {
  const IdVerificationReviewsScreen({super.key});

  @override
  State<IdVerificationReviewsScreen> createState() =>
      _IdVerificationReviewsScreenState();
}

class _IdVerificationReviewsScreenState
    extends State<IdVerificationReviewsScreen> {
  final AdminService _admin = AdminService();
  // Per-user in-flight lock so a double-tap can't fire two status
  // writes for the same submission.
  final Set<String> _busyUids = <String>{};

  Future<void> _resolve(AppUser submitter, IdVerificationStatus status) async {
    if (_busyUids.contains(submitter.uid)) return;
    final messenger = ScaffoldMessenger.of(context);
    final note = await _askForNote(status);
    if (!mounted) return;
    if (note == null) return; // user cancelled
    setState(() => _busyUids.add(submitter.uid));
    try {
      await _admin.setVerificationStatus(
        userId: submitter.uid,
        status: status,
        reviewerNote: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      // The Firestore stream is about to emit a new list without
      // this submitter (their status flipped away from "submitted"),
      // which removes this row from the ListView. Inserting a
      // SnackBar in the same microtask races that teardown and the
      // framework throws `_dependents.isEmpty`. Defer to the next
      // frame so the row removal finishes first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              status == IdVerificationStatus.verified
                  ? '${submitter.displayName} approved.'
                  : '${submitter.displayName} rejected.',
            ),
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't update verification. Try again."),
          ),
        );
      });
    } finally {
      // Mutate the busy set without `setState`. The stream emission
      // has already removed the row from the tree, so there's
      // nothing for the busy flag to gate; forcing another rebuild
      // here just compounds the same race.
      _busyUids.remove(submitter.uid);
    }
  }

  Future<String?> _askForNote(IdVerificationStatus status) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            status == IdVerificationStatus.verified
                ? 'Approve submission?'
                : 'Reject submission?',
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Reviewer note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(
                status == IdVerificationStatus.verified ? 'Approve' : 'Reject',
              ),
            ),
          ],
        );
      },
    );
    // Defer the controller dispose to the next frame so it doesn't
    // race the dialog overlay's exit animation. Calling dispose
    // synchronously while a descendant TextField is still in the
    // tree triggers the framework `_dependents.isEmpty` assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    if (!_admin.isAdmin(me)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const _NotAuthorisedView(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text('ID Verification Reviews'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: _admin.streamPendingIdVerifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pending = snapshot.data ?? const <AppUser>[];
            if (pending.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No pending submissions',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'When a user submits an ID for review, it will '
                        'appear here.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: pending.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final submitter = pending[index];
                return _PendingTile(
                  submitter: submitter,
                  busy: _busyUids.contains(submitter.uid),
                  onApprove: () =>
                      _resolve(submitter, IdVerificationStatus.verified),
                  onReject: () =>
                      _resolve(submitter, IdVerificationStatus.rejected),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final AppUser submitter;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingTile({
    required this.submitter,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final v = submitter.idVerification!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                size: 48,
                initials: submitter.initials,
                photoUrl: submitter.photoUrl,
                avatarId: submitter.avatarId,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submitter.displayName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((submitter.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        submitter.email!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(label: 'Document', value: v.documentType.label),
          _DetailRow(label: 'Legal name', value: v.fullName),
          _DetailRow(label: 'ID last 4', value: v.documentNumberLast4),
          _DetailRow(
            label: 'Expires',
            value:
                '${v.expiryDate.month.toString().padLeft(2, '0')}/'
                '${v.expiryDate.day.toString().padLeft(2, '0')}/'
                '${v.expiryDate.year}',
          ),
          if (v.issuingState != null && v.issuingState!.isNotEmpty)
            _DetailRow(label: 'Issuing state', value: v.issuingState!),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _ImageChip(label: 'Document (front)', url: v.documentFrontUrl),
              if ((v.documentBackUrl ?? '').isNotEmpty)
                _ImageChip(label: 'Document (back)', url: v.documentBackUrl!),
              if ((v.selfieUrl ?? '').isNotEmpty)
                _ImageChip(label: 'Selfie', url: v.selfieUrl!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(busy ? 'Working…' : 'Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageChip extends StatelessWidget {
  final String label;
  final String url;
  const _ImageChip({required this.label, required this.url});

  void _openPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text("Couldn't load image."),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPreview(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotAuthorisedView extends StatelessWidget {
  const _NotAuthorisedView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Admin only',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in with an admin account to review ID '
                'verification submissions.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
