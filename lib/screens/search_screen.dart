import 'package:flutter/material.dart';
import '../app.dart';
import '../models/marketplace.dart';
import '../widgets/common.dart';

/// Functional store & category search.
///
/// Lists every mock vendor and category from the catalogue, filters them live
/// as the shopper types, and lets them drill into a store preview (with its
/// matching products) from the result rows.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
  }

  void _onCategoryTap(Category category) {
    setState(() {
      _selectedCategory =
          _selectedCategory == category.name ? null : category.name;
    });
  }

  List<Vendor> get _visibleStores {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? vendors
        : vendors
              .where((v) =>
                  v.name.toLowerCase().contains(q) ||
                  v.tagline.toLowerCase().contains(q))
              .toList();
    if (_selectedCategory == null) return list;
    final keyword = _categoryKeyword(_selectedCategory!);
    return list
        .where((v) =>
            keyword.isEmpty ||
            v.tagline.toLowerCase().contains(keyword) ||
            v.name.toLowerCase().contains(keyword))
        .toList();
  }

  List<Category> get _visibleCategories {
    final q = _query.trim().toLowerCase();
    return q.isEmpty
        ? categories
        : categories
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
  }

  void _openStore(BuildContext context, Vendor vendor) {
    final items = products.where((p) => p.vendorName == vendor.name).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CustomerApp.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _StoreSheet(
        vendor: vendor,
        products: items.isEmpty ? products.take(4).toList() : items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stores = _visibleStores;
    final cats = _visibleCategories;
    final resultsEmpty = stores.isEmpty && cats.isEmpty;

    return Scaffold(
      backgroundColor: CustomerApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: CustomerApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: true,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFE2E5EA), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: Color(0xFF9AA1AA), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Stores or categories…',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                    child: const Icon(Icons.close_rounded,
                        color: Color(0xFF9AA1AA), size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (cats.isNotEmpty) ...[
            _SectionLabel(
              title: _query.isEmpty ? 'Categories' : 'Matching categories',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats
                  .map(
                    (c) => _CategoryChip(
                      category: c,
                      selected: _selectedCategory == c.name,
                      onTap: () => _onCategoryTap(c),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          _SectionLabel(
            title: _query.isEmpty ? 'Stores' : 'Matching stores',
            count: stores.length,
          ),
          const SizedBox(height: 10),
          if (stores.isNotEmpty)
            ...stores.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StoreResultRow(
                  vendor: v,
                  onTap: () => _openStore(context, v),
                ),
              ),
            ),

          if (resultsEmpty) ...[
            const SizedBox(height: 40),
            const Icon(Icons.search_off_rounded,
                size: 56, color: Color(0xFFB7BDC5)),
            const SizedBox(height: 12),
            Text(
              'No stores or categories found',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search like "electronics" or "pizza".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Maps a category name to the vendor tagline it represents in the mock data.
String _categoryKeyword(String categoryName) {
  switch (categoryName) {
    case 'Restaurants':
      return 'Restaurant';
    case 'Electronics':
      return 'Electronics';
    case 'Groceries':
      return 'Groceries';
    case 'Health & Beauty':
      return 'Health & Beauty';
    case 'Gaming':
      return 'Gaming';
    case 'Services':
      return 'Services';
    default:
      return '';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: CustomerApp.brandGreenDark,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? category.color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? category.color : const Color(0xFFE2E5EA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon,
                size: 18,
                color: selected ? Colors.white : category.color),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : CustomerApp.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreResultRow extends StatelessWidget {
  const _StoreResultRow({required this.vendor, required this.onTap});

  final Vendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDF0F3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: vendor.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: RemoteImage(
                  url: vendor.logoUrl.isNotEmpty ? vendor.logoUrl : vendor.bannerUrl,
                  fallbackIcon: vendor.icon,
                  fallbackColor: vendor.color,
                  iconSize: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(vendor.tagline, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(vendor.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12)),
                        Text(' · ${vendor.reviews}+ reviews',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Text(vendor.eta, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: Color(0xFF9AA1AA)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Store detail shown from a search result.
class _StoreSheet extends StatelessWidget {
  const _StoreSheet({required this.vendor, required this.products});

  final Vendor vendor;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: vendor.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: RemoteImage(
                    url: vendor.logoUrl.isNotEmpty ? vendor.logoUrl : vendor.bannerUrl,
                    fallbackIcon: vendor.icon,
                    fallbackColor: vendor.color,
                    iconSize: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(
                        '${vendor.tagline} · ${vendor.eta} · '
                        '${vendor.rating.toStringAsFixed(1)}★ '
                        '(${vendor.reviews} reviews)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Popular this week', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...products.map(
              (p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CustomerApp.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: p.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: RemoteImage(
                            url: p.imageUrl,
                            fallbackIcon: p.icon,
                            fallbackColor: p.color,
                            iconSize: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                        PriceText(p.price, size: 13),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}