import 'package:flutter/material.dart';

/// Central marketplace domain types shared across every customer screen.
///
/// Single source of truth for entities and the mock catalogue, so vendors,
/// products, categories and orders stay consistent everywhere (DRY).

class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.tagline,
    required this.rating,
    required this.reviews,
    required this.eta,
    required this.color,
    required this.icon,
    this.bannerUrl = '',
    this.logoUrl = '',
    this.address = '',
    this.openingHours = '08:00',
    this.closingHours = '22:00',
    this.deliveryFee = 500,
    this.estimatedTime = '22-32 min',
    this.ratingCount = 0,
    this.isVerified = false,
    this.isActive = true,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final String tagline;
  final double rating;
  final int reviews;
  final String eta;
  final Color color;
  final IconData icon;
  final String bannerUrl;
  final String logoUrl;
  final String address;
  final String openingHours;
  final String closingHours;
  final double deliveryFee;
  final String estimatedTime;
  final int ratingCount;
  final bool isVerified;
  final bool isActive;
  final double? lat;
  final double? lng;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.vendorName,
    required this.unit,
    required this.price,
    required this.color,
    required this.icon,
    this.imageUrl = '',
    this.tag,
    this.category,
  });

  final String id;
  final String name;
  final String vendorName;
  final String unit;
  final int price; // whole naira units
  final Color color;
  final IconData icon;
  final String imageUrl; // optional product photo from the vendor panel
  final String? tag; // optional promo label, e.g. "-20%"
  final String? category; // category name when sourced from the API
}

class Category {
  const Category({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final IconData icon;
  final Color color;
}

class Order {
  const Order({
    required this.id,
    required this.vendor,
    required this.summary,
    required this.meta,
    required this.amount,
    required this.status,
    required this.color,
    required this.icon,
  });

  final String id;
  final String vendor;
  final String summary;
  final String meta;
  final int amount;
  final String status; // Processing | In Transit | Delivered
  final Color color;
  final IconData icon;
}

/// The order statuses shared with the marketgo-vendor panel.
const List<String> orderStatuses = ['Processing', 'In Transit', 'Delivered'];

/// Stable accent palette used to decorate API-sourced cards by name.
const List<Color> brandPalette = [
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFF7C3AED),
  Color(0xFFDC2626),
  Color(0xFFF97316),
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFF0891B2),
];

/// Deterministic color for any string (category, store…) so the same entity
/// keeps the same visual accent across rebuilds.
Color colorFor(String seed) {
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return brandPalette[hash % brandPalette.length];
}

/// Maps a backend icon slug (e.g. "local_grocery_store") to a Material icon.
IconData categoryIcon(String? slug) {
  switch (slug) {
    case 'checkroom':
      return Icons.checkroom_rounded;
    case 'devices':
      return Icons.devices_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'spa':
      return Icons.spa_rounded;
    case 'storefront':
      return Icons.storefront_rounded;
    case 'local_grocery_store':
      return Icons.local_grocery_store_rounded;
    default:
      return Icons.category_rounded;
  }
}

// ---------------------------------------------------------------------------
// Mock catalogue (stands in for data served by marketgo-api)
// ---------------------------------------------------------------------------

const List<Vendor> vendors = [
  Vendor(
    id: 'v1',
    name: 'KFC',
    tagline: 'Restaurant',
    rating: 4.6,
    reviews: 2840,
    eta: '25–35 min',
    color: Color(0xFFB91C1C),
    icon: Icons.restaurant_rounded,
  ),
  Vendor(
    id: 'v2',
    name: 'Computer Village',
    tagline: 'Electronics',
    rating: 4.7,
    reviews: 1204,
    eta: '30–45 min',
    color: Color(0xFF2563EB),
    icon: Icons.computer_rounded,
  ),
  Vendor(
    id: 'v3',
    name: 'The Games',
    tagline: 'Gaming',
    rating: 4.8,
    reviews: 543,
    eta: '20–30 min',
    color: Color(0xFF0F172A),
    icon: Icons.sports_esports_rounded,
  ),
  Vendor(
    id: 'v4',
    name: 'Market Square',
    tagline: 'Groceries',
    rating: 4.5,
    reviews: 3200,
    eta: '15–25 min',
    color: Color(0xFF16A34A),
    icon: Icons.storefront_rounded,
  ),
  Vendor(
    id: 'v5',
    name: 'Shoprite',
    tagline: 'Groceries',
    rating: 4.4,
    reviews: 5120,
    eta: '30–40 min',
    color: Color(0xFFDC2626),
    icon: Icons.shopping_cart_rounded,
  ),
  Vendor(
    id: 'v6',
    name: 'Health Plus',
    tagline: 'Health & Beauty',
    rating: 4.7,
    reviews: 890,
    eta: '25–35 min',
    color: Color(0xFF059669),
    icon: Icons.local_pharmacy_rounded,
  ),
  Vendor(
    id: 'v7',
    name: 'Apple Store',
    tagline: 'Electronics',
    rating: 4.9,
    reviews: 4100,
    eta: '20–30 min',
    color: Color(0xFF334155),
    icon: Icons.phone_iphone_rounded,
  ),
  Vendor(
    id: 'v8',
    name: 'Tecno',
    tagline: 'Electronics',
    rating: 4.5,
    reviews: 2300,
    eta: '20–30 min',
    color: Color(0xFF2563EB),
    icon: Icons.smartphone_rounded,
  ),
  Vendor(
    id: 'v9',
    name: "Domino's Pizza",
    tagline: 'Restaurant',
    rating: 4.6,
    reviews: 1840,
    eta: '30–45 min',
    color: Color(0xFFDC2626),
    icon: Icons.local_pizza_rounded,
  ),
  Vendor(
    id: 'v10',
    name: 'GameStop',
    tagline: 'Gaming',
    rating: 4.6,
    reviews: 670,
    eta: '25–35 min',
    color: Color(0xFFBE123C),
    icon: Icons.sports_esports_rounded,
  ),
  Vendor(
    id: 'v11',
    name: 'SPAR',
    tagline: 'Groceries',
    rating: 4.6,
    reviews: 2980,
    eta: '25–40 min',
    color: Color(0xFF15803D),
    icon: Icons.local_grocery_store_rounded,
  ),
  Vendor(
    id: 'v12',
    name: 'Quickteller',
    tagline: 'Services',
    rating: 4.3,
    reviews: 1450,
    eta: 'Instant',
    color: Color(0xFFF97316),
    icon: Icons.credit_card_rounded,
  ),
];

const List<Category> categories = [
  Category(
      name: 'Restaurants',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFEF4444)),
  Category(
      name: 'Electronics',
      icon: Icons.devices_rounded,
      color: Color(0xFF2563EB)),
  Category(
      name: 'Groceries',
      icon: Icons.local_grocery_store_rounded,
      color: Color(0xFF16A34A)),
  Category(
      name: 'Health & Beauty',
      icon: Icons.health_and_safety_rounded,
      color: Color(0xFFEC4899)),
  Category(
      name: 'Fashion',
      icon: Icons.checkroom_rounded,
      color: Color(0xFF7C3AED)),
  Category(
      name: 'More',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF6B7280)),
];

const List<Product> products = [
  Product(
    id: 'p1',
    name: 'Kick Clear Sneakers',
    vendorName: 'Kicks & Co',
    unit: 'per pair',
    price: 82000,
    color: Color(0xFF2563EB),
    icon: Icons.checkroom_rounded,
    tag: '-15%',
  ),
  Product(
    id: 'p2',
    name: 'Leather Handbag',
    vendorName: 'Lagos Threads',
    unit: 'each',
    price: 78000,
    color: Color(0xFF7C3AED),
    icon: Icons.work_outline,
  ),
  Product(
    id: 'p3',
    name: 'Wireless Earbuds',
    vendorName: 'GadgetHub',
    unit: 'each',
    price: 45000,
    color: Color(0xFF0EA5E9),
    icon: Icons.headphones_rounded,
    tag: '-10%',
  ),
  Product(
    id: 'p4',
    name: 'Glow Vitamin-C Serum',
    vendorName: 'Glow Beauty',
    unit: 'per 30ml',
    price: 12500,
    color: Color(0xFFEC4899),
    icon: Icons.spa_rounded,
  ),
  Product(
    id: 'p5',
    name: 'Denim Bomber Jacket',
    vendorName: 'Lagos Threads',
    unit: 'each',
    price: 64000,
    color: Color(0xFF4F46E5),
    icon: Icons.style_rounded,
  ),
  Product(
    id: 'p6',
    name: 'Smart Watch Series 6',
    vendorName: 'GadgetHub',
    unit: 'each',
    price: 118000,
    color: Color(0xFF0891B2),
    icon: Icons.watch_rounded,
    tag: '-20%',
  ),
  Product(
    id: 'p7',
    name: 'Import Rice (10kg)',
    vendorName: 'FreshMart NG',
    unit: 'per bag',
    price: 28500,
    color: Color(0xFF16A34A),
    icon: Icons.rice_bowl_rounded,
  ),
  Product(
    id: 'p8',
    name: 'Power Bank 20K',
    vendorName: 'GadgetHub',
    unit: 'each',
    price: 18500,
    color: Color(0xFF22C55E),
    icon: Icons.battery_charging_full_rounded,
  ),
];

/// Products surfaced on the storefront "Deals & bestsellers" shelf.
final List<Product> featuredProducts = products.take(6).toList();

const List<Order> orders = [
  Order(
    id: 'ORD-2049',
    vendor: 'Kicks & Co',
    summary: 'Kick Clear Sneakers ×2',
    meta: 'Arriving today, 6:40 PM',
    amount: 164000,
    status: 'In Transit',
    color: Color(0xFF2563EB),
    icon: Icons.delivery_dining_rounded,
  ),
  Order(
    id: 'ORD-2048',
    vendor: 'GadgetHub',
    summary: 'Wireless Earbuds ×1',
    meta: 'Ready for dispatch · 20 min',
    amount: 45000,
    status: 'Processing',
    color: Color(0xFF0EA5E9),
    icon: Icons.schedule_rounded,
  ),
  Order(
    id: 'ORD-2047',
    vendor: 'Lagos Threads',
    summary: 'Leather Handbag ×1',
    meta: 'Delivered Sep 4',
    amount: 78000,
    status: 'Delivered',
    color: Color(0xFF7C3AED),
    icon: Icons.style_rounded,
  ),
  Order(
    id: 'ORD-2046',
    vendor: 'FreshMart NG',
    summary: '7-item grocery box',
    meta: 'Delivered Sep 2',
    amount: 18350,
    status: 'Delivered',
    color: Color(0xFF16A34A),
    icon: Icons.local_grocery_store_rounded,
  ),
];

/// The live order being tracked on the storefront and orders tab.
Order get activeOrder => orders.firstWhere((o) => o.status == 'In Transit');