import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  void _openDocument(BuildContext context, _LegalDoc doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _LegalDocumentPage(doc: doc)),
    );
  }

  Widget _legalRow(BuildContext context, String title, _LegalDoc doc) {
    return InkWell(
      onTap: () => _openDocument(context, doc),
      child: Container(
        height: 64,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFD8F3DC), width: 2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(fontSize: 16),
              ),
            ),
            Text(
              'View',
              style: AppTextStyles.action.copyWith(
                color: AppColors.brightGreen,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_new_rounded,
              color: AppColors.brightGreen,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFC8F3CE),

        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).padding.top + 96,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                color: AppColors.white,

                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 24,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.chevron_left,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),

                    Text('Legal', style: AppTextStyles.pageTitle),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              _legalRow(context, 'Privacy Policy', _LegalDoc.privacy),
              _legalRow(context, 'Terms of Service', _LegalDoc.terms),

              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which static legal document to render. Content lives in
/// [_LegalDocumentPage] so the row → page wiring stays declarative.
enum _LegalDoc { privacy, terms }

/// Static, app-local Privacy Policy / Terms of Service viewer.
///
/// Content is intentionally project-appropriate plain text rather
/// than production legal copy. The intent is to make the rows on
/// [LegalPage] open something readable instead of dead-ending — a
/// real production app would replace these with reviewed legal
/// documents (typically loaded from a CMS or embedded asset).
class _LegalDocumentPage extends StatelessWidget {
  final _LegalDoc doc;

  const _LegalDocumentPage({required this.doc});

  String get _title =>
      doc == _LegalDoc.privacy ? 'Privacy Policy' : 'Terms of Service';

  List<_LegalSection> get _sections {
    final updated = 'Last updated: May 30, 2026';
    if (doc == _LegalDoc.privacy) {
      return [
        _LegalSection(
          heading: 'About this policy',
          body:
              "RallyUp is a student-built sports community app. This "
              'Privacy Policy explains, in plain language, what data we '
              'collect about you, why we collect it, and how you can '
              'control it. By using RallyUp you agree to this policy.\n\n'
              '$updated',
        ),
        _LegalSection(
          heading: 'Information you give us',
          body:
              "When you create an account we ask for an email address "
              'and a password. During onboarding you may share your '
              'name, date of birth, profile photo, sports you play, '
              'availability windows, a short bio, and your approximate '
              'location (we use your city + GPS coordinates to compute '
              'distance to nearby players and courts). You can edit or '
              'delete any of these from the Profile tab at any time.',
        ),
        _LegalSection(
          heading: 'Information we generate',
          body:
              "When you book a court, host an open match, send an "
              'invite, send a chat message, or receive a notification, '
              'we create records inside Cloud Firestore. These records '
              'are used to power the corresponding feature (My '
              'Bookings, Match Details, Messages, Notifications). We '
              'do not sell this data and we do not share it with any '
              'third-party advertiser.',
        ),
        _LegalSection(
          heading: 'Who can see your profile',
          body:
              "By default, other RallyUp users can find your profile "
              'through Nearby Players and Open Matches. You can hide '
              'your profile from discovery at any time by turning off '
              '"Profile Visibility" in Account Settings. Once hidden, '
              'your profile will not appear in Nearby Players, and '
              'other users will not be able to invite you to new open '
              'matches. Existing direct conversations and open matches '
              'you have already joined remain accessible.',
        ),
        _LegalSection(
          heading: 'Location data',
          body:
              "We ask for your device location once during onboarding "
              'so we can place you on the map and compute distance to '
              'players and courts. You can decline the permission and '
              'still use the app — RallyUp will then fall back to your '
              'manually picked city. We never share your precise GPS '
              'coordinates with other users; nearby distance is shown '
              'as a rounded value (e.g. "2.3 mi").',
        ),
        _LegalSection(
          heading: 'Notifications and push',
          body:
              "If you allow push notifications, we store a Firebase "
              'Cloud Messaging token for your device so we can notify '
              'you about new invites, match updates, and direct '
              'messages. You can revoke this permission from your '
              'device system settings at any time.',
        ),
        _LegalSection(
          heading: 'Identity verification',
          body:
              "ID verification is optional. If you choose to submit "
              'documents (a government-issued ID and a selfie), they '
              'are uploaded over a secure connection to our image '
              'storage provider (Cloudinary) and reviewed by a member '
              "of the RallyUp team. We don't sell, share, or use these "
              'documents for any purpose other than verifying your '
              'identity.',
        ),
        _LegalSection(
          heading: 'Deleting your account',
          body:
              "You can delete your RallyUp account from Profile → "
              'Account Settings → Delete Account. Deleting your account '
              'removes your user profile, hides your past activity '
              'from discovery, and revokes future access. Historical '
              'booking, match, invite, and chat records may be retained '
              'for a short period to preserve other users\' experience '
              '(e.g. so a host\'s past matches still render for the '
              'players who joined). Cancellation of pending invites '
              'happens automatically.',
        ),
        _LegalSection(
          heading: 'Contacting us',
          body:
              "Questions or concerns about your data? Use Profile → "
              'Feedback & Suggestions to send us a message. We read '
              'every submission and respond as soon as we can.',
        ),
      ];
    }
    return [
      _LegalSection(
        heading: 'About these terms',
        body:
            "These Terms of Service describe the rules for using "
            'RallyUp. By creating an account or opening the app you '
            'agree to these terms. If you do not agree, please stop '
            'using the app.\n\n'
            '$updated',
      ),
      _LegalSection(
        heading: 'Who can use RallyUp',
        body:
            "RallyUp is intended for people aged 13 and older. You "
            'must give accurate information when creating your account, '
            'keep your password secure, and not impersonate another '
            'person. You are responsible for everything that happens '
            'on your account.',
      ),
      _LegalSection(
        heading: 'Real-world meetups',
        body:
            "RallyUp helps you find players and book courts. Anything "
            'that happens during an actual match — travel to the '
            'venue, conduct on the court, injuries, lost belongings, '
            'or disputes between players — is your responsibility, not '
            'RallyUp\'s. Use common sense, treat other players with '
            'respect, and meet in public places.',
      ),
      _LegalSection(
        heading: 'Bookings and payments',
        body:
            "Court bookings inside RallyUp are time reservations only. "
            'Any payment for court time, equipment, or other costs is '
            'handled directly between you and the host, the venue, or '
            'other players — RallyUp does not collect or process those '
            'payments today.',
      ),
      _LegalSection(
        heading: 'Open matches and invites',
        body:
            "When you host an open match, you commit to showing up at "
            'the venue and time you posted, or to cancelling the match '
            'in good time if your plans change. When you accept an '
            'invite or join an open match, you make the same '
            'commitment. Repeatedly hosting and cancelling matches at '
            'the last minute, or accepting invites without showing up, '
            'may result in your account being restricted.',
      ),
      _LegalSection(
        heading: 'Acceptable use',
        body:
            "Do not use RallyUp to harass, threaten, or send unwanted "
            'messages to other users. Do not post offensive content, '
            'spam, or impersonate someone else. If another user '
            'violates these rules, tap "Report" on their profile or '
            'send us a message through Feedback & Suggestions and we '
            'will review the report.',
      ),
      _LegalSection(
        heading: 'Suspension and termination',
        body:
            "We may suspend or terminate accounts that violate these "
            'terms, abuse the platform, or put other users at risk. '
            'You can close your own account at any time from Account '
            'Settings → Delete Account.',
      ),
      _LegalSection(
        heading: 'Changes to these terms',
        body:
            "We may update these terms occasionally to reflect new "
            'features or community guidelines. We will surface major '
            'changes inside the app. Continuing to use RallyUp after '
            'an update means you accept the new terms.',
      ),
      _LegalSection(
        heading: 'No warranty',
        body:
            "RallyUp is provided as-is, without warranties of any "
            'kind. We do our best to keep the app working and your '
            'data safe, but we cannot guarantee uninterrupted service '
            'and we are not liable for indirect or consequential '
            'damages arising from your use of the app.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFC8F3CE),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).padding.top + 96,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                color: AppColors.white,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 24,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.chevron_left,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                    Text(_title, style: AppTextStyles.pageTitle),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.white,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 40),
                    children: [
                      for (final section in _sections) ...[
                        Text(
                          section.heading,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section.body,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection({required this.heading, required this.body});
}
