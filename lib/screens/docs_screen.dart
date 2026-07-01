import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';

class DocsScreen extends StatelessWidget {
  const DocsScreen({super.key});

  static const _docs = [
    ('Japan itinerary draft.pdf', 'PDF', '2.1 MB', 'Nov 10'),
    ('Hotel confirmations.pdf', 'PDF', '840 KB', 'Nov 8'),
    ('Rail pass receipt.jpg', 'Image', '1.3 MB', 'Nov 9'),
    ('Travel insurance.pdf', 'PDF', '3.7 MB', 'Nov 5'),
    ('Visa documents.pdf', 'PDF', '1.1 MB', 'Oct 28'),
    ('Expense tracker.xlsx', 'Sheet', '56 KB', 'Nov 11'),
  ];

  static const _typeIcons = {
    'PDF': Icons.picture_as_pdf_rounded,
    'Image': Icons.image_rounded,
    'Sheet': Icons.table_chart_rounded,
  };

  static const _typeColors = {
    'PDF': kColorDanger,
    'Image': kColorSecondary,
    'Sheet': kColorSuccess,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Documents', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded),
            color: kColorInkSoft,
            onPressed: () {},
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(kSpace4),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: kSpace3,
          crossAxisSpacing: kSpace3,
          childAspectRatio: 0.85,
        ),
        itemCount: _docs.length,
        itemBuilder: (context, i) {
          final (name, type, size, date) = _docs[i];
          final icon = _typeIcons[type] ?? Icons.insert_drive_file_rounded;
          final iconColor = _typeColors[type] ?? kColorInkSoft;

          return DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              borderRadius: kRadiusLg,
              child: InkWell(
                onTap: () {},
                borderRadius: kRadiusLg,
                highlightColor: kColorPrimarySoft,
                splashColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(kSpace4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: kColorSurfaceSunken,
                          borderRadius: kRadiusMd,
                        ),
                        child: Icon(icon, size: 22, color: iconColor),
                      ),
                      const Spacer(),
                      Text(
                        name,
                        style: kStyleCaptionMedium.copyWith(color: kColorInk),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: kSpace1),
                      Text(
                        '$size · $date',
                        style: kStyleOverline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
