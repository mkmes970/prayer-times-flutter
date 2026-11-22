import 'package:flutter/material.dart';

/// A searchable alternative to a clipped dropdown in rotated phone browsers.
/// The result is a draft; the existing settings Save button still commits it.
class RegionSelector extends StatelessWidget {
  const RegionSelector({
    required this.options,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });

  final Map<String, String> options;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('المنطقة الحالية'),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const Key('region-selector'),
          icon: const Icon(Icons.search),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              options[selectedId] ?? 'اختر المنطقة',
              textAlign: TextAlign.center,
            ),
          ),
          onPressed: () async {
            final id = await showDialog<String>(
              context: context,
              builder: (_) => _RegionDialog(
                options: options,
                selectedId: selectedId,
              ),
            );
            if (context.mounted && id != null) onChanged(id);
          },
        ),
        Text(
          'اضغط لاختيار المنطقة أو البحث باسم القرية — ${options.length} مناطق',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RegionDialog extends StatefulWidget {
  const _RegionDialog({required this.options, required this.selectedId});

  final Map<String, String> options;
  final String? selectedId;

  @override
  State<_RegionDialog> createState() => _RegionDialogState();
}

class _RegionDialogState extends State<_RegionDialog> {
  final _scroll = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _normalize(String text) => text
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final results = widget.options.entries
        .where((entry) => _normalize(entry.value).contains(_normalize(_query)))
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختيار المنطقة — ${widget.options.length} مناطق',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('region-search'),
                decoration: const InputDecoration(
                  labelText: 'ابحث باسم القرية أو المنطقة',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() => _query = value);
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                },
              ),
              const SizedBox(height: 8),
              Flexible(
                child: results.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد منطقة مطابقة للاسم.'),
                      )
                    : Scrollbar(
                        controller: _scroll,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _scroll,
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final entry = results[index];
                            return ListTile(
                              key: ValueKey('region-${entry.key}'),
                              title: Text(entry.value),
                              trailing: entry.key == widget.selectedId
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => Navigator.of(context).pop(entry.key),
                            );
                          },
                        ),
                      ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
