/// Cloudinary configuration for unsigned uploads.
///
/// These values are NOT secrets — `cloudName` is in every uploaded URL and
/// `uploadPreset` is registered as unsigned in your Cloudinary dashboard.
/// Setup steps:
///
///   1. Create a free account at https://cloudinary.com.
///   2. Note your `cloud_name` from the dashboard.
///   3. Settings → Upload → Add upload preset:
///        - Name: rallyup_unsigned
///        - Signing mode: Unsigned
///        - Allowed formats: jpg, png, webp, heic
///        - Max file size: 10 MB
///        - Use auto-generated public_id (keeps URLs unguessable)
///   4. Replace the placeholders below with your values.
class CloudinaryConfig {
  /// Replace with the cloud name shown on your Cloudinary dashboard.
  static const String cloudName = 'dvgkos78l';

  /// Name of the unsigned upload preset created above.
  static const String uploadPreset = 'rallyup_app';

  /// Folder for profile photos. Cloudinary will create this lazily.
  static const String profilePhotoFolder = 'rallyup/profile-photos';

  /// Folder for ID verification documents. Long, auto-generated public_ids
  /// keep individual URLs effectively unguessable; the URL is only stored
  /// in the user's Firestore doc behind auth rules.
  static const String idVerificationFolder = 'rallyup/id-verification';

  // Sanity check that the placeholder was actually replaced. We check
  // against the original template string, NEVER against a live cloud
  // name — otherwise the moment the placeholder gets replaced this guard
  // turns into a false-negative and breaks uploads.
  static bool get isConfigured =>
      cloudName.isNotEmpty && cloudName != 'YOUR_CLOUD_NAME';

  static Uri get uploadEndpoint =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
}
