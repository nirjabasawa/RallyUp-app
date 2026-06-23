import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class BlockListPage extends StatelessWidget {
  const BlockListPage({super.key});

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

                    Text('Blocked Users', style: AppTextStyles.pageTitle),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Text(
                    'No Users Blocked',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
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
