import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/signup_form_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/login_text_field.dart';
import '../../widgets/primary_button.dart';
import 'photo_screen.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late final TextEditingController firstNameController;
  late final TextEditingController lastNameController;

  String? firstNameError;
  String? lastNameError;

  @override
  void initState() {
    super.initState();
    final form = context.read<SignupFormProvider>();
    firstNameController = TextEditingController(text: form.firstName);
    lastNameController = TextEditingController(text: form.lastName);
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  String? _validateName(String value, {required bool required}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return required ? 'First name is required' : null;
    }
    if (trimmed.length < AppUser.minNameLength) {
      return 'Must be at least ${AppUser.minNameLength} characters';
    }
    if (trimmed.length > AppUser.maxNameLength) {
      return 'Must be ${AppUser.maxNameLength} characters or fewer';
    }
    return null;
  }

  void continueToPhoto() {
    final firstNameValid = _validateName(
      firstNameController.text,
      required: true,
    );
    final lastNameValid = _validateName(
      lastNameController.text,
      required: false,
    );
    setState(() {
      firstNameError = firstNameValid;
      lastNameError = lastNameValid;
    });

    if (firstNameValid != null || lastNameValid != null) return;

    context.read<SignupFormProvider>().setName(
      firstName: firstNameController.text,
      lastName: lastNameController.text,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhotoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 54),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.chevron_left,
                            color: AppColors.darkGreen,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "What's your name?",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkGray,
                          ),
                        ),
                        const SizedBox(height: 28),
                        LoginTextField(
                          label: 'First Name *',
                          controller: firstNameController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppUser.maxNameLength,
                            ),
                          ],
                        ),
                        if (firstNameError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            firstNameError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        LoginTextField(
                          label: 'Last Name',
                          controller: lastNameController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppUser.maxNameLength,
                            ),
                          ],
                        ),
                        if (lastNameError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            lastNameError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Center(
                          child: PrimaryButton(
                            text: 'Continue',
                            width: 180,
                            height: 48,
                            backgroundColor: AppColors.darkGreen.withValues(
                              alpha: 0.75,
                            ),
                            onPressed: continueToPhoto,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
