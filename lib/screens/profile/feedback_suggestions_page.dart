import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';

class FeedbackSuggestionsPage extends StatefulWidget {
  const FeedbackSuggestionsPage({super.key});

  @override
  State<FeedbackSuggestionsPage> createState() =>
      _FeedbackSuggestionsPageState();
}

class _FeedbackSuggestionsPageState extends State<FeedbackSuggestionsPage> {
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final FeedbackService _feedbackService = FeedbackService();

  // Placeholder text doubles as a hint inside the category field; we
  // strip it before sending so it's never persisted as the real
  // category.
  static const String _categoryPlaceholder =
      'Technical issue, bug, feedback...';

  bool _submitting = false;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    categoryController.text = _categoryPlaceholder;
  }

  @override
  void dispose() {
    categoryController.dispose();
    descriptionController.dispose();
    super.dispose();
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
              padding: EdgeInsets.symmetric(horizontal: 56),
              child: Text(
                'Feedback & Suggestions',
                textAlign: TextAlign.center,
                style: AppTextStyles.pageTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: AppTextStyles.body.copyWith(fontSize: 20));
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(
        color: AppColors.textSecondary,
        fontSize: 18,
      ),
      filled: true,
      fillColor: const Color(0xFFEDEDED),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  /// Validate + persist the form. Writes to `feedback/{id}` via
  /// [FeedbackService]. The signed-in user's uid + email + display
  /// name are attached when available so a moderator can follow up;
  /// anonymous submissions (no signed-in user) still work.
  Future<void> _submitFeedback() async {
    if (_submitting) return;
    final description = descriptionController.text.trim();
    if (description.isEmpty) {
      setState(
        () => _descriptionError = 'Please describe what you want to share.',
      );
      return;
    }
    // Strip the placeholder back to the canonical "Feedback" bucket
    // when the user didn't type a custom category.
    var category = categoryController.text.trim();
    if (category.isEmpty || category == _categoryPlaceholder) {
      category = 'Feedback';
    }

    final messenger = ScaffoldMessenger.of(context);
    final me = context.read<AuthProvider>().currentUser;
    setState(() {
      _submitting = true;
      _descriptionError = null;
    });
    try {
      await _feedbackService.submitFeedback(
        message: description,
        category: category,
        userId: me?.uid,
        userEmail: me?.email,
        userName: me?.displayName,
      );
      if (!mounted) return;
      // Clear the form so a second submission can't be sent by
      // accident, and pop back to Profile.
      descriptionController.clear();
      categoryController.text = _categoryPlaceholder;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thank you. Your feedback has been submitted.'),
        ),
      );
      Navigator.maybePop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't submit your feedback. Please try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),

              const SizedBox(height: 42),

              _label('Category'),

              const SizedBox(height: 8),

              TextField(
                controller: categoryController,
                decoration: _inputDecoration(),
              ),

              const SizedBox(height: 26),

              _label('Description'),

              const SizedBox(height: 8),

              TextField(
                controller: descriptionController,
                maxLines: 9,
                decoration: _inputDecoration(
                  hint: 'Please give a detailed explanation of\nthe problem',
                ),
                onChanged: (_) {
                  if (_descriptionError != null) {
                    setState(() => _descriptionError = null);
                  }
                },
              ),

              if (_descriptionError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _descriptionError!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],

              const SizedBox(height: 76),

              Center(
                child: PrimaryButton(
                  text: _submitting ? 'Submitting…' : 'Submit',
                  width: 300,
                  height: 58,
                  backgroundColor: AppColors.primary,
                  onPressed: _submitting ? () {} : _submitFeedback,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
