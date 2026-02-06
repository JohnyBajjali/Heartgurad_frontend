import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart' as launcher;

class EcgGalleryScreen extends StatefulWidget {
  const EcgGalleryScreen({super.key});

  @override
  State<EcgGalleryScreen> createState() => _EcgGalleryScreenState();
}

class _EcgGalleryScreenState extends State<EcgGalleryScreen> {
  final _searchCtrl = TextEditingController();
  String _category = 'All';

  bool _loading = true;
  String? _error;

  List<_EcgDiseaseItem> _items = const [];

  static const _classLabel = <String, String>{
    'MI': 'Ischemia / MI',
    'STTC': 'ST-T Changes',
    'CD': 'Conduction',
    'HYP': 'Hypertrophy',
    'NORM': 'Normal',
  };

  @override
  void initState() {
    super.initState();
    _loadCsv();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCsv() async {
    try {
      final csv = await rootBundle.loadString('assets/data/scp_statementsRegrouped2.csv');
      final rows = _parseCsvToMaps(csv);

      debugPrint('CSV rows parsed = ${rows.length}');

      final items = rows.map(_EcgDiseaseItem.fromCsv).toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load ECG CSV: $e';
      });
    }
  }

  /// CSV parser with quote support + BOM/header cleanup.
  /// Also fixes first empty header -> "code" automatically.
  static List<Map<String, String>> _parseCsvToMaps(String input) {
    final rows = <List<String>>[];
    final row = <String>[];
    final cell = StringBuffer();
    bool inQuotes = false;

    void endCell() {
      row.add(cell.toString());
      cell.clear();
    }

    void endRow() {
      endCell();
      rows.add(List<String>.from(row));
      row.clear();
    }

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];

      if (inQuotes) {
        if (ch == '"') {
          final nextIsQuote = (i + 1 < input.length) && input[i + 1] == '"';
          if (nextIsQuote) {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(ch);
        }
        continue;
      }

      if (ch == '"') {
        inQuotes = true;
        continue;
      }

      if (ch == ',') {
        endCell();
        continue;
      }

      if (ch == '\n') {
        endRow();
        continue;
      }

      if (ch == '\r') continue;

      cell.write(ch);
    }

    if (cell.isNotEmpty || row.isNotEmpty) endRow();
    if (rows.isEmpty) return const [];

    // Clean headers: remove BOM and fix first empty header -> "code"
    final headers = rows.first.map((h) => h.replaceAll('\uFEFF', '').trim()).toList();
    if (headers.isNotEmpty && headers[0].isEmpty) headers[0] = 'code';

    final out = <Map<String, String>>[];
    for (final r in rows.skip(1)) {
      if (r.every((v) => v.trim().isEmpty)) continue;
      final m = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        final key = headers[i];
        final val = (i < r.length) ? r[i] : '';
        m[key] = val;
      }
      out.add(m);
    }
    return out;
  }

  List<String> get _categories {
    final set = <String>{'All'};
    for (final it in _items) {
      if (it.classKey.isNotEmpty) set.add(it.classKey);
    }

    final list = set.toList();
    list.sort((a, b) {
      if (a == 'All') return -1;
      if (b == 'All') return 1;
      const order = ['MI', 'STTC', 'CD', 'HYP', 'NORM'];
      final ia = order.indexOf(a);
      final ib = order.indexOf(b);
      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      return a.compareTo(b);
    });

    return list;
  }

  List<_EcgDiseaseItem> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _items.where((it) {
      final matchesCategory = _category == 'All' ? true : it.classKey == _category;
      if (!matchesCategory) return false;

      if (q.isEmpty) return true;

      return it.title.toLowerCase().contains(q) ||
          it.code.toLowerCase().contains(q) ||
          it.description.toLowerCase().contains(q) ||
          it.subclass.toLowerCase().contains(q);
    }).toList();
  }

  // -------- SMART SEARCH QUERY --------
  String _smartSearchQuery(_EcgDiseaseItem item) {
    String clean(String s) {
      return s.replaceAll(RegExp(r'\(.*?\)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final desc = clean(item.description);
    final sub = clean(item.subclass);
    final code = item.code.trim();

    final lower = desc.toLowerCase();
    if (code == 'EL' || lower.contains('electroly')) {
      return 'electrolyte ECG OR hyperkalemia ECG OR hypokalemia ECG OR digoxin ECG site:litfl.com';
    }
    if (lower.contains('non-specific') && (lower.contains('st') || lower.contains('t'))) {
      return 'ST depression ECG OR ST elevation ECG OR T wave inversion ECG site:litfl.com';
    }
    if (lower.contains('ischemic') && item.classKey == 'STTC') {
      return 'ischemia ECG ST depression ECG T wave inversion site:litfl.com';
    }

    final base = (sub.isNotEmpty && sub.length >= 3) ? sub : desc;
    final classHint = _classLabel[item.classKey] ?? item.classKey;
    final query = '$base ECG $classHint site:litfl.com';

    return query.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _openReference(_EcgDiseaseItem item) async {
    final raw = item.url.trim();

    if (raw.isNotEmpty) {
      final u = Uri.tryParse(raw);
      if (u != null && (u.scheme == 'http' || u.scheme == 'https')) {
        await launcher.launchUrl(u, mode: launcher.LaunchMode.externalApplication);
        return;
      }
    }

    final q = Uri.encodeComponent(_smartSearchQuery(item));
    final google = Uri.parse('https://www.google.com/search?q=$q');
    await launcher.launchUrl(google, mode: launcher.LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '12-Lead ECG Gallery',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      '${filtered.length} items',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.60)),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search (e.g., STEMI, AFib, LBBB...)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((c) {
                    final selected = _category == c;
                    final label = c == 'All' ? 'All' : (_classLabel[c] ?? c);
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final crossAxisCount = w >= 1100 ? 4 : (w >= 820 ? 3 : (w >= 520 ? 2 : 1));

                    return GridView.builder(
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.0,
                      ),
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final classLabel =
                        item.classKey.isEmpty ? null : (_classLabel[item.classKey] ?? item.classKey);

                        return _EcgCard(
                          item: item,
                          classLabel: classLabel,
                          onOpen: () => _openReference(item),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Note: Some SCP statements are broad. If no direct page exists, "Open" will search LITFL automatically.',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.60)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EcgCard extends StatelessWidget {
  final _EcgDiseaseItem item;
  final String? classLabel;
  final VoidCallback onOpen;

  const _EcgCard({
    required this.item,
    required this.onOpen,
    this.classLabel,
  });

  IconData get _icon {
    if (item.classKey == 'MI') return Icons.warning_amber_rounded;
    if (item.classKey == 'CD') return Icons.multiline_chart_rounded;
    if (item.classKey == 'HYP') return Icons.favorite_rounded;
    if (item.classKey == 'STTC') return Icons.show_chart_rounded;
    return Icons.monitor_heart_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ✅ theme-based card color
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.10),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (classLabel != null) _chip(context, classLabel!),
                  if (item.subclass.isNotEmpty) _chip(context, item.subclass),
                  _chip(context, item.diagnostic == true ? 'Diagnostic' : 'Non-diagnostic'),
                ],
              ),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Reference',
                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open'),
              ),
            ],
          )
        ],
      ),
    );
  }

  static Widget _chip(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // ✅ theme-based chip surface
        color: cs.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EcgDiseaseItem {
  final String code;
  final String description;
  final String classKey;
  final String subclass;
  final bool? diagnostic;
  final String url;

  const _EcgDiseaseItem({
    required this.code,
    required this.description,
    required this.classKey,
    required this.subclass,
    required this.diagnostic,
    required this.url,
  });

  String get title => code.isEmpty ? description : '$code — $description';

  static _EcgDiseaseItem fromCsv(Map<String, String> m) {
    String g(String k) => (m[k] ?? '').trim();

    final diagRaw = g('diagnostic');
    bool? diagnostic;
    if (diagRaw.isNotEmpty) {
      final v = double.tryParse(diagRaw);
      diagnostic = (v != null) ? v >= 1.0 : (diagRaw.toLowerCase() == 'true');
    }

    return _EcgDiseaseItem(
      code: g('code'),
      description: g('description'),
      classKey: g('diagnostic_class'),
      subclass: g('diagnostic_subclass'),
      diagnostic: diagnostic,
      url: g('url'),
    );
  }
}