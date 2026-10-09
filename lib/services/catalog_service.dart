import 'package:flutter/material.dart';
import '../models/api.dart';
import '../models/marketplace.dart';
import 'api_client.dart';

/// Loads the marketplace catalogue (categories, stores, products) from the
/// marketgo-api public endpoints.
///
/// The public catalog endpoints are unauthenticated, so this works before
/// login. If the API is unreachable the service degrades gracefully to the
/// bundled demo catalogue so the storefront stays explorable standalone.
class CatalogService {
  CatalogService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  bool get _offline => api.isOffline;

  Future<List<Category>> categories() async => _adaptCategories(await _get(
        '/api/v1/customer/categories',
        key: 'categories',
        fallback: () => List<Category>.of(mockCategories.values),
      ));

  Future<List<Vendor>> stores() async => _adaptStores(await _get(
        '/api/v1/customer/stores',
        key: 'stores',
        fallback: null,
      ));

  Future<List<Product>> products() async => _adaptProducts(await _get(
        '/api/v1/customer/products',
        key: 'products',
        fallback: null,
      ));

  /// Categories and products that power the storefront grid. Uses API data
  /// when reachable, otherwise the bundled demo catalogue.
  Future<CatalogSnapshot> snapshot() async {
    if (_offline) {
      return CatalogSnapshot(
        categories: List.of(mockCategories.values),
        vendors: mockVendors,
        products: mockProducts,
        fromApi: false,
      );
    }
    try {
      final data = await Future.wait([
        _get('/api/v1/customer/categories', key: 'categories', fallback: null),
        _get('/api/v1/customer/stores', key: 'stores', fallback: null),
        _get('/api/v1/customer/products', key: 'products', fallback: null),
      ]);
      final categories = _adaptCategories(data[0]);
      final stores = _adaptStores(data[1]);
      final products = _adaptProducts(data[2]);
      if (products.isEmpty) {
        return CatalogSnapshot(
          categories: categories,
          vendors: stores.isEmpty ? mockVendors : stores,
          products: mockProducts,
          fromApi: stores.isNotEmpty,
        );
      }
      return CatalogSnapshot(
        categories: categories,
        vendors: stores,
        products: products,
        fromApi: true,
      );
    } catch (_) {
      return CatalogSnapshot(
        categories: List.of(mockCategories.values),
        vendors: mockVendors,
        products: mockProducts,
        fromApi: false,
      );
    }
  }

  Future<List<dynamic>> _get(
    String path, {
    required String key,
    required List<dynamic> Function()? fallback,
  }) async {
    if (_offline && fallback != null) return fallback();
    final data = await api.get(path);
    final list = data[key];
    if (list is List) return list;
    return fallback?.call() ?? const [];
  }
}

/// Snapshot of the storefront catalogue from either the API or the bundled
/// demo data ([fromApi] reports the source).
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.categories,
    required this.vendors,
    required this.products,
    required this.fromApi,
  });

  final List<Category> categories;
  final List<Vendor> vendors;
  final List<Product> products;
  final bool fromApi;
}

List<Category> _adaptCategories(List<dynamic> raw) => raw
    .map((e) => ApiCategory.fromJson(e as Map<String, dynamic>))
    .map((c) => Category(
          name: c.name,
          icon: categoryIcon(c.icon),
          color: colorFor(c.name),
        ))
    .toList();

List<Vendor> _adaptStores(List<dynamic> raw) => raw
    .map((e) => ApiStore.fromJson(e as Map<String, dynamic>))
    .map((s) => Vendor(
          id: '${s.id}',
          name: s.name,
          tagline: s.description.isEmpty ? 'Store' : s.description,
          rating: s.rating,
          reviews: s.ratingCount,
          eta: s.estimatedTime,
          color: colorFor(s.name),
          icon: Icons.storefront_rounded,
          bannerUrl: s.bannerUrl,
          logoUrl: s.logoUrl,
          address: s.address,
          openingHours: s.openingHours,
          closingHours: s.closingHours,
          deliveryFee: s.deliveryFee,
          estimatedTime: s.estimatedTime,
          ratingCount: s.ratingCount,
          isVerified: s.isVerified,
          lat: s.lat,
          lng: s.lng,
        ))
    .toList();

List<Product> _adaptProducts(List<dynamic> raw) => raw
    .map((e) => ApiProduct.fromJson(e as Map<String, dynamic>))
    .map((p) {
      final categoryName = p.category?.name ?? p.store?.name ?? p.name;
      final color = colorFor(categoryName);
      return Product(
        id: '${p.id}',
        name: p.name,
        vendorName: p.store?.name ?? 'MarketGO',
        unit: p.unit.isEmpty ? 'each' : p.unit,
        price: p.price.round(),
        color: color,
        icon: categoryIcon(p.category?.icon) == Icons.category_rounded
            ? Icons.inventory_2_rounded
            : categoryIcon(p.category?.icon),
        imageUrl: p.imageUrl,
        category: p.category?.name,
      );
    })
    .toList();

// ---------------------------------------------------------------------------
// Bundled demo catalogue (used only when the API is unreachable).
// ---------------------------------------------------------------------------

/// Mock category index preserved from the original prototype.
final Map<String, Category> mockCategories = {
  for (final c in categories) c.name: c,
};

const List<Vendor> mockVendors = vendors;
const List<Product> mockProducts = products;