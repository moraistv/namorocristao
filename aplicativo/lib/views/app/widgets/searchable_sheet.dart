import 'package:flutter/material.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';

/// Abre um bottom sheet com busca e retorna o item escolhido (ou null).
Future<T?> showSearchableSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) label,
  String Function(T)? prefix,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SearchableSheet<T>(
      title: title,
      items: items,
      label: label,
      prefix: prefix,
    ),
  );
}

class _SearchableSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) label;
  final String Function(T)? prefix;
  const _SearchableSheet({
    required this.title,
    required this.items,
    required this.label,
    this.prefix,
  });

  @override
  State<_SearchableSheet<T>> createState() => _SearchableSheetState<T>();
}

class _SearchableSheetState<T> extends State<_SearchableSheet<T>> {
  String _q = "";

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((e) => widget.label(e).toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: const Color(0xFFE0E3EB),
                  borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: "Buscar...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  return ListTile(
                    leading: widget.prefix != null
                        ? Text(widget.prefix!(item),
                            style: const TextStyle(fontSize: 24))
                        : null,
                    title: Text(widget.label(item)),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
