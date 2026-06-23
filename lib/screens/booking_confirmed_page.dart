import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rallyup/screens/main_shell_nav.dart';
import 'package:rallyup/screens/my_bookings_page.dart';

import '../models/booking.dart';
import '../theme/app_colors.dart';
import '../widgets/courts/court_network_image.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/sport_emoji.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/primary_button.dart';

/// Post-booking success screen. Now takes a real [Booking] rather
/// than a bag of strings, so every field shown here is the same data
/// the BookingService persisted to Firestore — no more hard-coded
/// court names, dates, or price totals.
///
/// Match-type / players-needed / cost-split visuals that the
/// previous version rendered are intentionally gone — they were
/// scaffolding for the open-match phase and didn't reflect anything
/// that the BookingService actually stores.
class BookingConfirmedPage extends StatelessWidget {
  final Booking booking;

  const BookingConfirmedPage({super.key, required this.booking});

  void _openShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Match',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 16),
              _ShareOptionTile(
                icon: Icons.chat_rounded,
                title: 'WhatsApp',
                onTap: () => Navigator.pop(context),
              ),
              _ShareOptionTile(
                icon: Icons.link_rounded,
                title: 'Copy Link',
                onTap: () => Navigator.pop(context),
              ),
              _ShareOptionTile(
                icon: Icons.share_rounded,
                title: 'More',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMyBookings(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MyBookingsPage(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    switchToMainShellTab(context, index);
  }

  String _formatTime(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: h, minute: m));
  }

  @override
  Widget build(BuildContext context) {
    final emoji = sportEmojiFor(booking.sportType);
    final dateText = DateFormat('EEE, MMM d, y').format(booking.date);
    final timeText =
        '${_formatTime(context, booking.startTime)} - '
        '${_formatTime(context, booking.endTime)}';
    final totalText = '\$${booking.totalPrice.toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                8,
                AppSpacing.pageHorizontal,
                20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    const SizedBox(height: 2),
                    const _ConfirmationGraphic(),
                    const SizedBox(height: 2),
                    Text(
                      'Booking Confirmed!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromARGB(18, 0, 0, 0),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                width: 150,
                                height: 110,
                                child: CourtNetworkImage(
                                  url: booking.courtImageUrl,
                                  iconSize: 32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      booking.courtName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (booking.courtAddress.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        booking.courtAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      '$emoji  ${booking.sportType}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      dateText,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      timeText,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SummaryRow(
                      label: 'Status',
                      value: booking.status.replaceFirstMapped(
                        RegExp(r'^.'),
                        (m) => m.group(0)!.toUpperCase(),
                      ),
                      valueColor: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'Price per hour',
                      value: '\$${booking.pricePerHour.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 14),
                    _SummaryRow(label: 'Total', value: totalText, isBold: true),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Share Match',
                      height: 48,
                      backgroundColor: AppColors.primary,
                      onPressed: () => _openShareOptions(context),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => _openMyBookings(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: Text(
                          'View My Bookings',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: (index) => _onBottomNavTap(context, index),
      ),
    );
  }
}

class _ConfirmationGraphic extends StatelessWidget {
  const _ConfirmationGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/confetti.png',
            width: 400,
            height: 400,
            fit: BoxFit.contain,
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFF1DB954),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTextStyles.bodyMedium.copyWith(
      fontSize: 15,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
      color: AppColors.textPrimary,
    );
    final valueStyle = AppTextStyles.bodyMedium.copyWith(
      fontSize: 15,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
      color: valueColor ?? AppColors.textPrimary,
    );

    return Row(
      children: [
        Text(label, style: labelStyle),
        const Spacer(),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
