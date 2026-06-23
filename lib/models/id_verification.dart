import 'package:cloud_firestore/cloud_firestore.dart';

enum IdDocumentType { driversLicense, passport, stateId }

extension IdDocumentTypeX on IdDocumentType {
  String get storageKey {
    switch (this) {
      case IdDocumentType.driversLicense:
        return 'drivers_license';
      case IdDocumentType.passport:
        return 'passport';
      case IdDocumentType.stateId:
        return 'state_id';
    }
  }

  String get label {
    switch (this) {
      case IdDocumentType.driversLicense:
        return "Driver's License";
      case IdDocumentType.passport:
        return 'Passport';
      case IdDocumentType.stateId:
        return 'State ID';
    }
  }

  /// Driver's License and State ID have a back side; Passport does not.
  bool get requiresBack => this != IdDocumentType.passport;

  /// Driver's License and State ID are state-issued; Passport is federal.
  bool get requiresIssuingState => this != IdDocumentType.passport;

  static IdDocumentType fromKey(String? key) {
    switch (key) {
      case 'passport':
        return IdDocumentType.passport;
      case 'state_id':
        return IdDocumentType.stateId;
      case 'drivers_license':
      default:
        return IdDocumentType.driversLicense;
    }
  }
}

enum IdVerificationStatus { submitted, verified, rejected }

extension IdVerificationStatusX on IdVerificationStatus {
  String get storageKey => name;

  static IdVerificationStatus fromKey(String? key) {
    switch (key) {
      case 'verified':
        return IdVerificationStatus.verified;
      case 'rejected':
        return IdVerificationStatus.rejected;
      case 'submitted':
      default:
        return IdVerificationStatus.submitted;
    }
  }
}

/// Submit-for-review ID record. The user-side submit flow only writes
/// `submitted`; verified/rejected transitions belong to the admin
/// flow ([AdminService.setVerificationStatus]).
class IdVerification {
  final IdDocumentType documentType;
  final String documentFrontUrl;
  final String? documentBackUrl;
  final String? selfieUrl;
  final String fullName;
  final String documentNumberLast4;
  final DateTime expiryDate;
  final String? issuingState;
  final IdVerificationStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerNote;

  const IdVerification({
    required this.documentType,
    required this.documentFrontUrl,
    this.documentBackUrl,
    this.selfieUrl,
    required this.fullName,
    required this.documentNumberLast4,
    required this.expiryDate,
    this.issuingState,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewerNote,
  });

  Map<String, dynamic> toMap() => {
    'documentType': documentType.storageKey,
    'documentFrontUrl': documentFrontUrl,
    'documentBackUrl': documentBackUrl,
    'selfieUrl': selfieUrl,
    'fullName': fullName,
    'documentNumberLast4': documentNumberLast4,
    'expiryDate': Timestamp.fromDate(expiryDate),
    'issuingState': issuingState,
    'status': status.storageKey,
    'submittedAt': Timestamp.fromDate(submittedAt),
    'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    'reviewerNote': reviewerNote,
  };

  factory IdVerification.fromMap(Map<String, dynamic> map) {
    return IdVerification(
      documentType: IdDocumentTypeX.fromKey(map['documentType'] as String?),
      documentFrontUrl: (map['documentFrontUrl'] as String?) ?? '',
      documentBackUrl: map['documentBackUrl'] as String?,
      selfieUrl: map['selfieUrl'] as String?,
      fullName: (map['fullName'] as String?) ?? '',
      documentNumberLast4: (map['documentNumberLast4'] as String?) ?? '',
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      issuingState: map['issuingState'] as String?,
      status: IdVerificationStatusX.fromKey(map['status'] as String?),
      submittedAt:
          (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      reviewerNote: map['reviewerNote'] as String?,
    );
  }

  /// Short status label shown alongside the user's name.
  static String labelFor(IdVerification? record) {
    if (record == null) return 'Unverified player';
    switch (record.status) {
      case IdVerificationStatus.verified:
        return 'Verified player';
      case IdVerificationStatus.submitted:
        return 'Verification pending';
      case IdVerificationStatus.rejected:
        return 'Unverified player';
    }
  }
}
