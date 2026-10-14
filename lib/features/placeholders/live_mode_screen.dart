import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/lt_widgets.dart';

class LiveModeScreen extends StatelessWidget {
  const LiveModeScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
      ),
      body: const ComingSoonBody(
        title: 'מצב Live',
        subtitle: 'מפה חיה, מזג אוויר, התקדמות יומית וכפתור AI יופיעו כאן ב‑v2. בינתיים השתמשו במפת המסלול.',
        emoji: '📍',
      ),
    );
  }
}
