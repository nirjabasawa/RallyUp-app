import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// What the picker tells the caller when it closes. `null` from the
/// modal-bottom-sheet means the user cancelled.
sealed class LocationPickerResult {
  const LocationPickerResult();
}

/// User wants to refresh from device GPS. The caller should run the
/// permission + capture flow and persist the result through AuthProvider.
class CurrentLocationRequest extends LocationPickerResult {
  const CurrentLocationRequest();
}

/// User picked one of the manual entries. `label` is the displayable
/// "City, ST" string.
class ManualLocationPick extends LocationPickerResult {
  final String label;
  const ManualLocationPick(this.label);
}

class LocationPickerSheet extends StatefulWidget {
  /// Currently displayed label so the matching row can show a check mark.
  /// Optional — leave null if no current selection should be highlighted.
  final String? currentLabel;

  const LocationPickerSheet({super.key, this.currentLabel});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _recentLocations = const [
    'Santa Clara, CA',
    'Sunnyvale, CA',
    'San Jose, CA',
  ];

  // A small curated quick-pick list. The text field below is the real
  // search/entry path — anything the user types that doesn't match one of
  // these is offered as a manual location via the fallback tile.
  final List<String> _suggestedLocations = const [
    'Palo Alto, CA',
    'Cupertino, CA',
    'Fremont, CA',
    'San Mateo, CA',
    'Mountain View, CA',
    'Redwood City, CA',
    'San Francisco, CA',
    'Oakland, CA',
    'Berkeley, CA',
  ];

  List<String> get _filteredRecentLocations {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _recentLocations;
    return _recentLocations
        .where((location) => location.toLowerCase().contains(query))
        .toList();
  }

  List<String> get _filteredSuggestedLocations {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _suggestedLocations;
    return _suggestedLocations
        .where((location) => location.toLowerCase().contains(query))
        .toList();
  }

  void _pickManual(String location) {
    Navigator.pop<LocationPickerResult>(context, ManualLocationPick(location));
  }

  void _pickCurrent() {
    Navigator.pop<LocationPickerResult>(
      context,
      const CurrentLocationRequest(),
    );
  }

  Widget _buildSectionCard(List<String> locations) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(locations.length, (index) {
          final location = locations[index];
          final isSelected = location == widget.currentLabel;

          return InkWell(
            borderRadius: index == 0
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : index == locations.length - 1
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            onTap: () => _pickManual(location),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: index == locations.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 28,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      location,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// True when the user typed something that doesn't match any curated
  /// row — in that case we offer "Use 'San Mateo'" as a manual location.
  bool get _shouldOfferManualEntry {
    final query = _searchController.text.trim();
    if (query.length < 2) return false;
    return _filteredRecentLocations.isEmpty &&
        _filteredSuggestedLocations.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final recentLocations = _filteredRecentLocations;
    final suggestedLocations = _filteredSuggestedLocations;
    final showManualEntry = _shouldOfferManualEntry;
    final manualQuery = _searchController.text.trim();

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Select location',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: _pickCurrent,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 30,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Current Location',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Get nearby courts around you',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 30,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 30,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search city or Area',
                          border: InputBorder.none,
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showManualEntry) ...[
                const SizedBox(height: 22),
                _ManualEntryTile(
                  query: manualQuery,
                  onTap: () => _pickManual(manualQuery),
                ),
              ],
              if (recentLocations.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'Recent Locations',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(recentLocations),
              ],
              if (suggestedLocations.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'Suggested Locations',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(suggestedLocations),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the user types something we don't have in the curated list.
/// Lets them commit the typed value as a manual location instead of being
/// stuck with no results.
class _ManualEntryTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;

  const _ManualEntryTile({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add_location_alt_outlined,
              size: 28,
              color: AppColors.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use "$query"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Set this as your location',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 28,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
