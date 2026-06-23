import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool monthlySelected = true;

  Widget buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Color(0xFFFFC327), size: 22),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPlan({
    required bool selected,
    required String title,
    required String price,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_box : Icons.check_box_outline_blank,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.body.copyWith(fontSize: 17)),
              const SizedBox(height: 4),
              Text(
                price,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void savePlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          monthlySelected ? 'Monthly plan selected' : 'Yearly plan selected',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 32, 34, 40),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.chevron_left,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                  Text(
                    'Manage Subscription',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.pageTitle,
                  ),
                ],
              ),

              const SizedBox(height: 42),

              Text(
                'Get Premium\nToday',
                textAlign: TextAlign.center,
                style: AppTextStyles.pageTitle.copyWith(fontSize: 34),
              ),

              const SizedBox(height: 10),

              Text(
                'Get access to exclusive features and get the most out of your \nexperience on RallyUp.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 36),

              buildFeature('Create Your Own Group'),
              buildFeature('Boost Profile Visibility'),
              buildFeature('Advanced Search Filters'),

              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF7E3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    buildPlan(
                      selected: monthlySelected,
                      title: 'Monthly',
                      price: '\$6.99 USD',
                      onTap: () {
                        setState(() {
                          monthlySelected = true;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    const Divider(color: Color(0xFFB8BDC6)),
                    const SizedBox(height: 22),
                    buildPlan(
                      selected: !monthlySelected,
                      title: 'Yearly',
                      price: '\$29.99 USD',
                      onTap: () {
                        setState(() {
                          monthlySelected = false;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 34),

              PrimaryButton(
                text: 'Save',
                width: 230,
                height: 56,
                backgroundColor: AppColors.primary,
                onPressed: savePlan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
