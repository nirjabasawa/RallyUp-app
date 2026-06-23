import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/location_picker_sheet.dart';
import 'location_service.dart';

/// Opens the picker and persists the choice through AuthProvider so
/// every header in the app picks it up. Returns true on save, false
/// on cancel / failure.
Future<bool> openLocationPicker(BuildContext context) async {
  final result = await showModalBottomSheet<LocationPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const LocationPickerSheet(),
  );

  if (result == null) return false;
  if (!context.mounted) return false;

  final auth = context.read<AuthProvider>();
  final messenger = ScaffoldMessenger.maybeOf(context);

  switch (result) {
    case CurrentLocationRequest():
      try {
        final captured = await LocationService().captureCurrent();
        await auth.updateLocation(captured);
        return true;
      } catch (_) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't read your location. Check location permission and try again.",
            ),
          ),
        );
        return false;
      }
    case ManualLocationPick(:final label):
      // Forward-geocode so the saved record has real lat/lng instead
      // of the (0, 0) fallback (which would break every distance
      // calculation in the app).
      try {
        final resolved = await LocationService().resolveManualLocation(label);
        await auth.updateLocation(resolved);
        return true;
      } catch (_) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't set that location. Please try another city.",
            ),
          ),
        );
        return false;
      }
  }
}
