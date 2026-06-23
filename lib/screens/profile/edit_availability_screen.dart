import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';

class EditAvailabilityScreen extends StatefulWidget {
  const EditAvailabilityScreen({super.key});

  @override
  State<EditAvailabilityScreen> createState() => _EditAvailabilityScreenState();
}

class _EditAvailabilityScreenState extends State<EditAvailabilityScreen> {
  static const List<String> _allDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  late Map<String, AvailabilitySlot> _slots;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current =
        context.read<AuthProvider>().currentUser?.availability ??
        const <String, AvailabilitySlot>{};
    _slots = Map<String, AvailabilitySlot>.from(current);
  }

  TimeOfDay _parse(String hhmm, {required TimeOfDay fallback}) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  String _format(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _display(TimeOfDay t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(t);

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickStart(String day) async {
    final current = _slots[day] ?? AvailabilitySlot.defaultSlot;
    final picked = await showTimePicker(
      context: context,
      initialTime: _parse(
        current.start,
        fallback: const TimeOfDay(hour: 18, minute: 0),
      ),
      helpText: 'Start time',
    );
    if (picked == null) return;
    final endTod = _parse(
      current.end,
      fallback: const TimeOfDay(hour: 21, minute: 0),
    );
    // If new start is after current end, push end one hour past start so the
    // window stays valid.
    final newEnd = _toMinutes(picked) >= _toMinutes(endTod)
        ? TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute)
        : endTod;
    setState(() {
      _slots[day] = AvailabilitySlot(
        start: _format(picked),
        end: _format(newEnd),
      );
    });
  }

  Future<void> _pickEnd(String day) async {
    final current = _slots[day] ?? AvailabilitySlot.defaultSlot;
    final picked = await showTimePicker(
      context: context,
      initialTime: _parse(
        current.end,
        fallback: const TimeOfDay(hour: 21, minute: 0),
      ),
      helpText: 'End time',
    );
    if (picked == null) return;
    final startTod = _parse(
      current.start,
      fallback: const TimeOfDay(hour: 18, minute: 0),
    );
    if (_toMinutes(picked) <= _toMinutes(startTod)) {
      setState(() {
        _error = 'End time must be after start time.';
      });
      return;
    }
    setState(() {
      _error = null;
      _slots[day] = AvailabilitySlot(
        start: current.start,
        end: _format(picked),
      );
    });
  }

  void _toggleDay(String day, bool next) {
    setState(() {
      _error = null;
      if (next) {
        _slots[day] = _slots[day] ?? AvailabilitySlot.defaultSlot;
      } else {
        _slots.remove(day);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Preserve canonical Mon-Sun ordering on the way out.
      final ordered = <String, AvailabilitySlot>{
        for (final d in _allDays)
          if (_slots.containsKey(d)) d: _slots[d]!,
      };
      await context.read<AuthProvider>().updateAvailability(ordered);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save availability. Please try again.';
      });
    }
  }

  Widget _dayRow(String day) {
    final slot = _slots[day];
    final isOn = slot != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 16),
                ),
              ),
              Switch.adaptive(
                value: isOn,
                activeThumbColor: AppColors.darkGreen,
                onChanged: (next) => _toggleDay(day, next),
              ),
            ],
          ),
          if (isOn) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _TimeChip(
                    label: 'Start',
                    value: _display(
                      _parse(
                        slot.start,
                        fallback: const TimeOfDay(hour: 18, minute: 0),
                      ),
                    ),
                    onTap: () => _pickStart(day),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeChip(
                    label: 'End',
                    value: _display(
                      _parse(
                        slot.end,
                        fallback: const TimeOfDay(hour: 21, minute: 0),
                      ),
                    ),
                    onTap: () => _pickEnd(day),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
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
                    'Availability',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Pick the days you’re usually available and set a time window for each.',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: _allDays.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFE3E6EA)),
                  itemBuilder: (context, index) => _dayRow(_allDays[index]),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: PrimaryButton(
                  text: _busy ? 'Saving…' : 'Save',
                  width: 180,
                  height: 50,
                  backgroundColor: AppColors.darkGreen,
                  onPressed: _busy ? () {} : _save,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
