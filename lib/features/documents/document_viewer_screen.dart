import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.tripId, required this.docId});
  final String tripId;
  final String docId;

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  Uint8List? _bytes;
  File? _cache;
  String? _error;
  TripDocument? _doc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await ref.read(documentsRepositoryProvider)?.forTrip(widget.tripId);
      final doc = docs?.where((d) => d.id == widget.docId).firstOrNull;
      if (doc == null) {
        setState(() => _error = 'המסמך לא נמצא');
        return;
      }
      _doc = doc;
      final bytes = await ref.read(documentsRepositoryProvider)!.download(doc.storagePath);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${doc.id}_${doc.storagePath.split('/').last}');
      await file.writeAsBytes(bytes, flush: true);
      setState(() {
        _bytes = bytes;
        _cache = file;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_doc?.title ?? 'מסמך'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _bytes == null
              ? const Center(child: CircularProgressIndicator())
              : (_doc?.isPdf == true && _cache != null)
                  ? PDFView(filePath: _cache!.path)
                  : InteractiveViewer(child: Image.memory(_bytes!)),
    );
  }
}
