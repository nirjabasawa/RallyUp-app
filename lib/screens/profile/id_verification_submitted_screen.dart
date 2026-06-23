import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/id_verification.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';

/// Final step of the prototype ID verification flow. Shows the user that
/// their submission has been recorded and reflects the current review
/// status from Firestore. There is no automated verification in Phase 2 —
/// `verified` / `rejected` transitions are admin-only.
class IdVerificationSubmittedScreen extends StatelessWidget {
  const IdVerificationSubmittedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final record = user?.idVerification;

    final status = record?.status ?? IdVerificationStatus.submitted;
    final submittedAt = record?.submittedAt ?? DateTime.now();

    final headline = switch (status) {
      IdVerificationStatus.submitted => 'Submitted for review',
      IdVerificationStatus.verified => 'ID verified',
      IdVerificationStatus.rejected => 'Review needed',
    };
    final icon = switch (status) {
      IdVerificationStatus.submitted => Icons.hourglass_top_rounded,
      IdVerificationStatus.verified => Icons.verified_rounded,
      IdVerificationStatus.rejected => Icons.error_outline_rounded,
    };
    final iconColor = switch (status) {
      IdVerificationStatus.submitted => AppColors.darkGreen,
      IdVerificationStatus.verified => AppColors.darkGreen,
      IdVerificationStatus.rejected => Colors.red,
    };
    final blurb = switch (status) {
      // Be honest: there is no automated verification and no live reviewer
      // pipeline yet. The status here is the source of truth for the user,
      // and stays as Pending until a reviewer manually updates it.
      IdVerificationStatus.submitted =>
        'Your ID and details have been saved to your account. There is no '
            "automated identity check in this build — a reviewer will "
            "update your status manually. Until then it stays Pending.",
      IdVerificationStatus.verified =>
        'Your ID has been verified by a reviewer.',
      IdVerificationStatus.rejected =>
        'Your submission needs another look. See the reviewer note below.',
    };

    final dateFmt = DateFormat('MMM d, y · h:mm a');

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        // Outer Column splits the screen into a scrolling body + an
        // anchored action footer. The previous Spacer-based layout
        // overflowed by ~37 px on shorter devices once the rejected note
        // was visible; making the body scroll fixes that without changing
        // the visual design.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.chevron_left,
                  color: AppColors.darkGreen,
                  size: 30,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Center(child: Icon(icon, color: iconColor, size: 80)),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          headline,
                          style: AppTextStyles.pageTitle.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          blurb,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (record != null) ...[
                        _kv('Document', record.documentType.label),
                        _kv('Submitted', dateFmt.format(submittedAt)),
                        if (record.issuingState != null &&
                            record.issuingState!.isNotEmpty)
                          _kv('Issuing state', record.issuingState!),
                        _kv(
                          'Expires',
                          DateFormat.yMMMd().format(record.expiryDate),
                        ),
                        _kv('Document #', '•••• ${record.documentNumberLast4}'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.lightGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your document images are stored privately '
                                  'and linked to your account. We only keep '
                                  'the last 4 digits of your document number '
                                  '— the full number is never saved.',
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (status == IdVerificationStatus.rejected &&
                            record.reviewerNote != null &&
                            record.reviewerNote!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Reviewer: ${record.reviewerNote!}',
                              style: AppTextStyles.body.copyWith(
                                fontSize: 14,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (status == IdVerificationStatus.rejected)
                Center(
                  child: PrimaryButton(
                    text: 'Resubmit',
                    width: 220,
                    height: 50,
                    backgroundColor: AppColors.darkGreen,
                    onPressed: () => Navigator.of(context).pop('resubmit'),
                  ),
                )
              else
                Center(
                  child: PrimaryButton(
                    text: 'Done',
                    width: 180,
                    height: 50,
                    backgroundColor: AppColors.darkGreen,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          k,
          style: AppTextStyles.body.copyWith(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          v,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
