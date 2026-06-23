import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/open_match.dart';
import '../providers/auth_provider.dart';
import '../services/booking_service.dart';
import '../services/invite_service.dart';
import '../services/open_match_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/sport_emoji.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/my_booking_list_card.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/side_menu_drawer.dart';
import 'booking_confirmed_page.dart';
import 'main_shell_nav.dart';
import 'player_details/match_details_page.dart';

/// Upcoming / Past view of the signed-in user's private bookings +
/// open matches. Bucketing is wall-clock — combining `date` +
/// `endTime` — so a session in progress reads correctly. Cancelled
/// rows always belong to Past so they disappear from Upcoming the
/// moment cancel succeeds.
class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final BookingService _bookingService = BookingService();
  final OpenMatchService _openMatchService = OpenMatchService();
  final InviteService _inviteService = InviteService();
  bool _showUpcoming = true;

  void _openBookingDetails(Booking booking) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => BookingConfirmedPage(booking: booking),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openMatchDetails(OpenMatch match) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => MatchDetailsPage(match: match),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Host-only "Cancel match" sheet. Runs the transactional cancel
  /// + sweeps pending invites into the cancelled state.
  void _openMatchHostOptions(OpenMatch match, AppUser host) {
    if (match.isCancelled) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: Text(
                  'Cancel match',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheetContext);
                  try {
                    await _openMatchService.cancelOpenMatch(
                      match: match,
                      host: host,
                    );
                    // Sweep pending invites into `cancelled`. Done
                    // from the UI to avoid a service-layer cycle
                    // (InviteService → OpenMatchService).
                    _inviteService
                        .cancelInvitesForMatch(match.id)
                        .catchError((_) {});
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Match cancelled')),
                    );
                  } on StateError catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(_cancelErrorText(e))),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text("Couldn't cancel this match. Try again."),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// "Leave match" sheet for a joined player. Transactional so a
  /// host-cancel can't race the leave.
  void _openMatchJoinedOptions(OpenMatch match, AppUser user) {
    if (match.isCancelled) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.exit_to_app_rounded,
                  color: Colors.red,
                ),
                title: Text(
                  'Leave match',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheetContext);
                  try {
                    await _openMatchService.leaveOpenMatch(
                      match: match,
                      user: user,
                    );
                    messenger.showSnackBar(
                      const SnackBar(content: Text('You left the match')),
                    );
                  } on StateError catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(_leaveErrorText(e))),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text("Couldn't leave this match. Try again."),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _cancelErrorText(StateError e) {
    switch (e.message) {
      case 'match-not-found':
        return 'This match no longer exists.';
      case 'not-host':
        return "You're not the host of this match.";
      case 'already-cancelled':
        return 'This match is already cancelled.';
      default:
        return "Couldn't cancel this match. Try again.";
    }
  }

  String _leaveErrorText(StateError e) {
    switch (e.message) {
      case 'match-not-found':
        return 'This match no longer exists.';
      case 'match-cancelled':
        return 'The host cancelled this match.';
      case 'host-cannot-leave':
        return 'Hosts cancel the match instead of leaving.';
      case 'not-joined':
        return "You aren't part of this match.";
      default:
        return "Couldn't leave this match. Try again.";
    }
  }

  void _openBookingOptions(Booking booking) {
    if (booking.isCancelled) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: Text(
                  'Cancel booking',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () async {
                  // Capture before the sheet pops.
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheetContext);
                  try {
                    await _bookingService.cancelBooking(booking.id);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Booking cancelled')),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Couldn't cancel this booking. Try again.",
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onBottomNavTap(int index) {
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

  /// `date` + `endTime` → wall-clock. A 6–7 PM booking today reads
  /// as Upcoming until 7 PM, then flips to Past.
  DateTime _bookingEndDateTime(Booking booking) {
    final parts = booking.endTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(
      booking.date.year,
      booking.date.month,
      booking.date.day,
      h,
      m,
    );
  }

  DateTime _matchEndDateTime(OpenMatch match) {
    final parts = match.endTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(match.date.year, match.date.month, match.date.day, h, m);
  }

  /// Start as wall-clock — used for the in-progress detection
  /// (`start ≤ now < end`).
  DateTime _bookingStartDateTime(Booking booking) {
    final parts = booking.startTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(
      booking.date.year,
      booking.date.month,
      booking.date.day,
      h,
      m,
    );
  }

  DateTime _matchStartDateTime(OpenMatch match) {
    final parts = match.startTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(match.date.year, match.date.month, match.date.day, h, m);
  }

  ({bool isUpcoming, bool isPast, bool isCancelled}) _bucketFor(
    Booking booking,
    DateTime now,
  ) {
    if (booking.isCancelled) {
      return (isUpcoming: false, isPast: true, isCancelled: true);
    }
    final endsAt = _bookingEndDateTime(booking);
    final isUpcoming = booking.isConfirmed && endsAt.isAfter(now);
    final isPast = booking.isConfirmed && endsAt.isBefore(now);
    return (isUpcoming: isUpcoming, isPast: isPast, isCancelled: false);
  }

  ({bool isUpcoming, bool isPast, bool isCancelled}) _matchBucketFor(
    OpenMatch match,
    DateTime now,
  ) {
    if (match.isCancelled) {
      return (isUpcoming: false, isPast: true, isCancelled: true);
    }
    final endsAt = _matchEndDateTime(match);
    return (
      isUpcoming: endsAt.isAfter(now),
      isPast: !endsAt.isAfter(now),
      isCancelled: false,
    );
  }

  String _tagFor(Booking booking, DateTime now) {
    if (booking.isCancelled) return 'Cancelled';
    final endsAt = _bookingEndDateTime(booking);
    if (!booking.isConfirmed || !endsAt.isAfter(now)) return 'Completed';
    final startsAt = _bookingStartDateTime(booking);
    if (!startsAt.isAfter(now)) return 'In progress';
    return 'Confirmed';
  }

  /// Cancelled / Completed / In progress / Hosting / Joined.
  String _matchTagFor(OpenMatch match, DateTime now, String myUid) {
    if (match.isCancelled) return 'Cancelled';
    final endsAt = _matchEndDateTime(match);
    if (!endsAt.isAfter(now)) return 'Completed';
    final startsAt = _matchStartDateTime(match);
    if (!startsAt.isAfter(now)) return 'In progress';
    return match.isHost(myUid) ? 'Hosting' : 'Joined';
  }

  /// Renders one card and routes its taps. [me] is passed so the
  /// More menu picks Cancel (host) vs Leave (joined) per row.
  Widget _buildRow(_Row row, DateTime now, AppUser me) {
    if (row.booking != null) {
      final b = row.booking!;
      final bucket = _bucketFor(b, now);
      final dateText = DateFormat('EEE, MMM d, y').format(b.date);
      final timeText =
          '${_formatTime(context, b.startTime)} - '
          '${_formatTime(context, b.endTime)}';
      return MyBookingListCard(
        imageUrl: b.courtImageUrl,
        title: b.courtName,
        sport: b.sportType,
        sportEmoji: sportEmojiFor(b.sportType),
        dateText: dateText,
        timeText: timeText,
        tagText: _tagFor(b, now),
        onTap: () => _openBookingDetails(b),
        onViewDetailsTap: () => _openBookingDetails(b),
        // Only upcoming confirmed bookings expose the More menu.
        onMoreTap: bucket.isUpcoming ? () => _openBookingOptions(b) : null,
      );
    }
    final m = row.match!;
    final bucket = _matchBucketFor(m, now);
    final dateText = DateFormat('EEE, MMM d, y').format(m.date);
    final timeText =
        '${_formatTime(context, m.startTime)} - '
        '${_formatTime(context, m.endTime)}';

    // Upcoming + host → Cancel; upcoming + joined → Leave;
    // past / cancelled → no menu.
    VoidCallback? onMoreTap;
    if (bucket.isUpcoming && !m.isCancelled) {
      if (m.isHost(me.uid)) {
        onMoreTap = () => _openMatchHostOptions(m, me);
      } else if (m.hasJoined(me.uid)) {
        onMoreTap = () => _openMatchJoinedOptions(m, me);
      }
    }

    return MyBookingListCard(
      imageUrl: m.courtImageUrl.isEmpty ? null : m.courtImageUrl,
      title: m.courtName,
      sport: m.sportType,
      sportEmoji: sportEmojiFor(m.sportType),
      dateText: dateText,
      timeText: timeText,
      tagText: _matchTagFor(m, now, me.uid),
      onTap: () => _openMatchDetails(m),
      onViewDetailsTap: () => _openMatchDetails(m),
      onMoreTap: onMoreTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final sectionTitle = _showUpcoming ? 'Upcoming Bookings' : 'Past Bookings';

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SideMenuDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                18,
                AppSpacing.pageHorizontal,
                10,
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      return IconButton(
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.menu_rounded,
                          size: 34,
                          color: AppColors.textPrimary,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 18),
                  Text(
                    'My Bookings',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const NotificationBellButton(size: 30),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
              ),
              child: Container(
                height: 56,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 241, 241, 241),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        label: 'Upcoming',
                        icon: Icons.calendar_today_outlined,
                        isSelected: _showUpcoming,
                        onTap: () => setState(() => _showUpcoming = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SegmentButton(
                        label: 'Past',
                        icon: Icons.history_toggle_off_rounded,
                        isSelected: !_showUpcoming,
                        onTap: () => setState(() => _showUpcoming = false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: me == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('Sign in to view your bookings.'),
                      ),
                    )
                  : StreamBuilder<List<Booking>>(
                      stream: _bookingService.streamBookingsForUser(me.uid),
                      builder: (context, bookingSnap) {
                        return StreamBuilder<List<OpenMatch>>(
                          stream: _openMatchService.streamMatchesForUser(
                            me.uid,
                          ),
                          builder: (context, matchSnap) {
                            // Wait for both streams' first frame so
                            // we don't flash the empty state.
                            final bothWaiting =
                                bookingSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !bookingSnap.hasData &&
                                matchSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !matchSnap.hasData;
                            if (bothWaiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            // Recompute `now` per rebuild so a row
                            // that ends while the page is open
                            // moves to Past on the next snapshot.
                            final now = DateTime.now();
                            final bookings =
                                bookingSnap.data ?? const <Booking>[];
                            final matches =
                                matchSnap.data ?? const <OpenMatch>[];

                            final rows = <_Row>[];
                            for (final b in bookings) {
                              final bucket = _bucketFor(b, now);
                              final include = _showUpcoming
                                  ? bucket.isUpcoming
                                  : (bucket.isPast || bucket.isCancelled);
                              if (!include) continue;
                              rows.add(
                                _Row(
                                  endsAt: _bookingEndDateTime(b),
                                  isUpcomingBucket: bucket.isUpcoming,
                                  booking: b,
                                ),
                              );
                            }
                            for (final m in matches) {
                              final bucket = _matchBucketFor(m, now);
                              final include = _showUpcoming
                                  ? bucket.isUpcoming
                                  : (bucket.isPast || bucket.isCancelled);
                              if (!include) continue;
                              rows.add(
                                _Row(
                                  endsAt: _matchEndDateTime(m),
                                  isUpcomingBucket: bucket.isUpcoming,
                                  match: m,
                                ),
                              );
                            }

                            // Upcoming: soonest-end first.
                            // Past: newest-end first.
                            rows.sort(
                              (a, b) => _showUpcoming
                                  ? a.endsAt.compareTo(b.endsAt)
                                  : b.endsAt.compareTo(a.endsAt),
                            );

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.pageHorizontal,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        sectionTitle,
                                        style: AppTextStyles.sectionTitle
                                            .copyWith(fontSize: 18),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Text(
                                          '${rows.length} bookings',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: rows.isEmpty
                                      ? _EmptyState(showUpcoming: _showUpcoming)
                                      : ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.pageHorizontal,
                                            0,
                                            AppSpacing.pageHorizontal,
                                            24,
                                          ),
                                          itemCount: rows.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 18),
                                          itemBuilder: (context, index) {
                                            return _buildRow(
                                              rows[index],
                                              now,
                                              me,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: _onBottomNavTap,
      ),
    );
  }
}

/// Unified row. Exactly one of [booking] or [match] is non-null.
/// Letting both shapes share one list keeps private bookings and
/// open matches interleaved by end-time without merging collections.
class _Row {
  final DateTime endsAt;
  final bool isUpcomingBucket;
  final Booking? booking;
  final OpenMatch? match;

  _Row({
    required this.endsAt,
    required this.isUpcomingBucket,
    this.booking,
    this.match,
  });
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool showUpcoming;
  const _EmptyState({required this.showUpcoming});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              showUpcoming ? 'No upcoming bookings' : 'No past bookings',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              showUpcoming
                  ? 'Book a court from the Courts tab to see it here.'
                  : "Bookings you've played will appear here.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
