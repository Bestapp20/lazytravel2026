import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class EditItemScreen extends ConsumerStatefulWidget {
  const EditItemScreen({super.key, required this.tripId, this.dayId, this.itemId});
  final String tripId;
  final String? dayId;
  final String? itemId;

  @override
  ConsumerState<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends ConsumerState<EditItemScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _map = TextEditingController();
  final _time = TextEditingController();
  String _category = 'attraction';
  double? _lat;
  double? _lng;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    if (widget.itemId == null) return;
    final days = await ref.read(tripsRepositoryProvider)?.daysFor(widget.tripId);
    TripItem? it;
    for (final d in days ?? []) {
      for (final i in d.items) {
        if (i.id == widget.itemId) it = i;
      }
    }
    if (it == null) return;
    _name.text = it.placeName;
    _address.text = it.address ?? '';
    _notes.text = it.notes ?? '';
    _map.text = it.mapLink ?? '';
    _time.text = it.startTime ?? '';
    _category = it.category ?? 'attraction';
    _lat = it.lat;
    _lng = it.lng;
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _notes.dispose();
    _map.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(tripsRepositoryProvider);
    var dayId = widget.dayId;
    if (repo == null) return;
    if (dayId == null || dayId.isEmpty) {
      final days = await repo.daysFor(widget.tripId);
      if (days.isEmpty) {
        final created = await repo.createDay(widget.tripId, 1, DateTime.now());
        dayId = created.id;
      } else {
        dayId = days.first.id;
      }
    }
    setState(() => _busy = true);
    try {
      await repo.upsertItem(
        {
          'trip_id': widget.tripId,
          'day_id': dayId,
          'place_name': _name.text.trim(),
          'category': _category,
          'address': _address.text.trim(),
          'notes': _notes.text.trim(),
          'map_link': _map.text.trim().isEmpty ? null : _map.text.trim(),
          'start_time': _time.text.trim().isEmpty ? null : _time.text.trim(),
          'lat': _lat,
          'lng': _lng,
        },
        id: widget.itemId,
      );
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(widget.itemId == null ? 'מקום חדש' : 'עריכת מקום'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(hintText: 'שם המקום')),
          const SizedBox(height: 10),
          TextField(controller: _address, decoration: const InputDecoration(hintText: 'כתובת')),
          const SizedBox(height: 10),
          TextField(controller: _time, decoration: const InputDecoration(hintText: 'שעה (09:00)')),
          const SizedBox(height: 10),
          TextField(controller: _map, decoration: const InputDecoration(hintText: 'קישור למפה')),
          const SizedBox(height: 10),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(hintText: 'הערות')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: const [
              DropdownMenuItem(value: 'attraction', child: Text('אטרקציה')),
              DropdownMenuItem(value: 'food', child: Text('אוכל')),
              DropdownMenuItem(value: 'hotel', child: Text('מלון')),
              DropdownMenuItem(value: 'museum', child: Text('מוזיאון')),
              DropdownMenuItem(value: 'nature', child: Text('טבע')),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'attraction'),
          ),
          const SizedBox(height: 20),
          LtPrimaryButton(label: _busy ? 'שומר...' : 'שמירה', onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}
