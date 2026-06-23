import 'package:flutter/material.dart';
import 'package:rallyup/screens/login/email_signup_screen.dart';
import 'package:rallyup/screens/login/phone_screen.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 430,
                      child: Image.asset(
                        'assets/images/map.png',
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'Find, Chat, Play',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        'Join RallyUp and meet new\npeople to level up your sports\nexperience!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          color: AppColors.darkGray,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    const SizedBox(height: 34),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 52),
                      child: PrimaryButton(
                        text: 'Continue with Phone',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PhoneScreen(),
                            ),
                          );
                        },
                        backgroundColor: AppColors.darkGreen,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 52),
                      child: PrimaryButton(
                        text: 'Continue with Email',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmailSignupScreen(),
                            ),
                          );
                        },
                        backgroundColor: AppColors.brightGreen,
                      ),
                    ),

                    const SizedBox(height: 34),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already an existing user?',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.black,
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          const SizedBox(width: 22),

                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/login');
                            },
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.darkGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
