import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider(tripId));
    final trip = ref.watch(tripProvider(tripId)).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('מסמכי הטיול'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
      ),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const ComingSoonBody(
              emoji: '📁',
              title: 'אין מסמכים עדיין',
              subtitle: 'העלו כרטיסי טיסה, שובר מלון או ביטוח — PDF או תמונה.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = list[i];
              final labels = {
                'flight': 'טיסה',
                'hotel': 'מלון',
                'insurance': 'ביטוח',
                'other': 'אחר',
              };
              return LtCard(
                onTap: () => context.push('/trips/$tripId/docs/${d.id}'),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.sectionTint,
                      child: Icon(d.isPdf ? Icons.picture_as_pdf : Icons.image, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.title, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
                          Text(labels[d.docType] ?? d.docType, style: GoogleFonts.notoSansHebrew(fontSize: 12, color: AppColors.textBody)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: AppColors.border),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: trip?.isOwner == true
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              onPressed: () => _upload(context, ref),
              label: Text('העלאה', style: GoogleFonts.notoSansHebrew(color: Colors.white, fontWeight: FontWeight.w700)),
              icon: const Icon(Icons.upload_file, color: Colors.white),
            )
          : null,
    );
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    var type = 'other';
    final title = TextEditingController();
    File? file;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('מסמך חדש', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(controller: title, decoration: const InputDecoration(hintText: 'כותרת (למשל כרטיס טיסה)')),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'flight', child: Text('טיסה')),
                  DropdownMenuItem(value: 'hotel', child: Text('מלון / שובר')),
                  DropdownMenuItem(value: 'insurance', child: Text('ביטוח')),
                  DropdownMenuItem(value: 'other', child: Text('אחר')),
                ],
                onChanged: (v) => setS(() => type = v ?? 'other'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LtSecondaryButton(
                      label: 'תמונה',
                      icon: Icons.photo,
                      onPressed: () async {
                        final x = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (x != null) setS(() => file = File(x.path));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LtSecondaryButton(
                      label: 'קובץ',
                      icon: Icons.attach_file,
                      onPressed: () async {
                        final r = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
                        );
                        if (r?.files.single.path != null) {
                          setS(() => file = File(r!.files.single.path!));
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (file != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(file!.path.split(Platform.pathSeparator).last, style: GoogleFonts.notoSansHebrew(fontSize: 12)),
                ),
              const SizedBox(height: 12),
              LtPrimaryButton(
                label: 'העלה',
                onPressed: file == null ? null : () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
    if (ok == true && file != null) {
      await ref.read(documentsRepositoryProvider)?.upload(
            tripId: tripId,
            file: file!,
            title: title.text.trim().isEmpty ? 'מסמך' : title.text.trim(),
            docType: type,
          );
      ref.invalidate(documentsProvider(tripId));
    }
  }
}
