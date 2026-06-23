import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/id_verification.dart';
import '../../providers/auth_provider.dart';
import '../../services/image_upload_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/login_text_field.dart';
import '../../widgets/primary_button.dart';
import 'id_verification_submitted_screen.dart';

/// Prototype "submit for review" flow. This screen captures everything a
/// human reviewer would need to validate a US-style government ID — but
/// does NOT perform any automated verification (no OCR, no face match, no
/// third-party verifier). On submit, images go to Cloudinary, metadata
/// goes to Firestore with `status: 'submitted'`, and the user lands on the
/// "Submitted" screen.
class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  final ImageUploadService _uploadService = ImageUploadService();

  IdDocumentType _documentType = IdDocumentType.driversLicense;
  File? _front;
  File? _back;
  File? _selfie;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _docNumberController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  DateTime? _expiryDate;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _docNumberController.dispose();
    _stateController.dispose();
    _uploadService.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(String slot) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      switch (slot) {
        case 'front':
          _front = File(picked.path);
          break;
        case 'back':
          _back = File(picked.path);
          break;
        case 'selfie':
          _selfie = File(picked.path);
          break;
      }
    });
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  String? _validate() {
    if (_front == null) return 'Capture the front of your document.';
    if (_documentType.requiresBack && _back == null) {
      return 'Capture the back of your document.';
    }
    if (_fullNameController.text.trim().length < 2) {
      return 'Enter the full name as printed on the document.';
    }
    final docNumber = _docNumberController.text.replaceAll(RegExp(r'\s'), '');
    if (docNumber.length < 4) return 'Enter your document number.';
    if (_expiryDate == null) return 'Pick the document expiry date.';
    if (_documentType.requiresIssuingState &&
        _stateController.text.trim().length != 2) {
      return 'Enter the 2-letter issuing state code (e.g. CA).';
    }
    return null;
  }

  Future<void> _submit() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    // Capture before async gap.
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'You need to be signed in.');
      return;
    }
    final navigator = Navigator.of(context);

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final frontUrl = await _uploadService.uploadIdDocument(
        _front!,
        uid: uid,
        slot: 'front',
      );
      String? backUrl;
      if (_back != null) {
        backUrl = await _uploadService.uploadIdDocument(
          _back!,
          uid: uid,
          slot: 'back',
        );
      }
      String? selfieUrl;
      if (_selfie != null) {
        selfieUrl = await _uploadService.uploadIdDocument(
          _selfie!,
          uid: uid,
          slot: 'selfie',
        );
      }

      final docNumber = _docNumberController.text.replaceAll(RegExp(r'\s'), '');
      final last4 = docNumber.length >= 4
          ? docNumber.substring(docNumber.length - 4)
          : docNumber;

      final record = IdVerification(
        documentType: _documentType,
        documentFrontUrl: frontUrl,
        documentBackUrl: backUrl,
        selfieUrl: selfieUrl,
        fullName: _fullNameController.text.trim(),
        documentNumberLast4: last4,
        expiryDate: _expiryDate!,
        issuingState: _documentType.requiresIssuingState
            ? _stateController.text.trim().toUpperCase()
            : null,
        status: IdVerificationStatus.submitted,
        submittedAt: DateTime.now(),
      );

      await auth.submitIdVerification(record);
      if (!mounted) return;

      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const IdVerificationSubmittedScreen(),
        ),
      );
    } on ImageUploadException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Submission failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showStateField = _documentType.requiresIssuingState;
    final showBackCapture = _documentType.requiresBack;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.chevron_left,
                      color: AppColors.darkGreen,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Verify your ID',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'This is a submit-for-review prototype — a human reviewer '
                'checks each submission. No automated identity check is '
                'performed in this build.',
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              _sectionLabel('Document type'),
              const SizedBox(height: 8),
              ...IdDocumentType.values.map(_docTypeOption),
              const SizedBox(height: 22),
              _sectionLabel('Document photo (front)'),
              const SizedBox(height: 8),
              _CapturePane(
                label: 'Tap to capture front',
                file: _front,
                onTap: _busy ? null : () => _pickDocument('front'),
              ),
              if (showBackCapture) ...[
                const SizedBox(height: 14),
                _sectionLabel('Document photo (back)'),
                const SizedBox(height: 8),
                _CapturePane(
                  label: 'Tap to capture back',
                  file: _back,
                  onTap: _busy ? null : () => _pickDocument('back'),
                ),
              ],
              const SizedBox(height: 14),
              _sectionLabel('Selfie (optional)'),
              const SizedBox(height: 8),
              _CapturePane(
                label: 'Tap to take a selfie',
                file: _selfie,
                onTap: _busy ? null : () => _pickDocument('selfie'),
              ),
              const SizedBox(height: 22),
              _sectionLabel('Details'),
              const SizedBox(height: 8),
              LoginTextField(
                label: 'Full name (as on document)',
                controller: _fullNameController,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              LoginTextField(
                label: 'Document number (we only store the last 4)',
                controller: _docNumberController,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
              ),
              if (showStateField) ...[
                const SizedBox(height: 14),
                LoginTextField(
                  label: 'Issuing state (e.g. CA)',
                  controller: _stateController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(2)],
                ),
              ],
              const SizedBox(height: 14),
              _ExpiryRow(
                expiry: _expiryDate,
                onTap: _busy ? null : _pickExpiry,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 26),
              Center(
                child: PrimaryButton(
                  text: _busy ? 'Submitting…' : 'Submit for review',
                  width: 240,
                  height: 50,
                  backgroundColor: AppColors.darkGreen,
                  onPressed: _busy ? () {} : _submit,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: AppTextStyles.bodyMedium.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _docTypeOption(IdDocumentType type) {
    final selected = _documentType == type;
    return InkWell(
      onTap: _busy
          ? null
          : () => setState(() {
              _documentType = type;
              if (!type.requiresBack) _back = null;
              if (!type.requiresIssuingState) _stateController.clear();
            }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.darkGreen : AppColors.grayText,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(type.label, style: AppTextStyles.body.copyWith(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _CapturePane extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback? onTap;

  const _CapturePane({
    required this.label,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? AppColors.darkGreen : Colors.transparent,
            width: 2,
          ),
          image: file != null
              ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover)
              : null,
        ),
        alignment: Alignment.center,
        child: file == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.darkGreen,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Retake',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  final DateTime? expiry;
  final VoidCallback? onTap;

  const _ExpiryRow({required this.expiry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = expiry == null
        ? 'Pick a date'
        : DateFormat.yMMMd().format(expiry!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.darkGreen,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              'Expiry: ',
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
