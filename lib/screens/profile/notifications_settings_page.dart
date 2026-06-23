import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool enableNotifications = true;
  bool chatNotifications = true;
  bool eventReminders = true;
  bool bookingNotifications = true;

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: AppTextStyles.body.copyWith(fontSize: 20)),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.white,
          activeTrackColor: AppColors.brightGreen,
          inactiveThumbColor: AppColors.white,
          inactiveTrackColor: AppColors.textSecondary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_left,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Manage Notifications',
                textAlign: TextAlign.center,
                style: AppTextStyles.pageTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Column(
            children: [
              _header(context),

              const SizedBox(height: 70),

              _switchRow(
                title: 'Enable Notifications',
                value: enableNotifications,
                onChanged: (value) {
                  setState(() {
                    enableNotifications = value;
                  });
                },
              ),

              const SizedBox(height: 86),

              _switchRow(
                title: 'Chat Notifications',
                value: chatNotifications,
                onChanged: (value) {
                  setState(() {
                    chatNotifications = value;
                  });
                },
              ),

              const SizedBox(height: 34),

              _switchRow(
                title: 'Event Reminders',
                value: eventReminders,
                onChanged: (value) {
                  setState(() {
                    eventReminders = value;
                  });
                },
              ),

              const SizedBox(height: 34),

              _switchRow(
                title: 'Booking Notifications',
                value: bookingNotifications,
                onChanged: (value) {
                  setState(() {
                    bookingNotifications = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
