import 'package:customer/models/cart.dart';
import 'package:customer/models/marketplace.dart';
import 'package:customer/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currency formatting preserves fractional amounts', () {
    expect(formatPrice(1520.5), '₦1,520.50');
    expect(formatPrice(82000), '₦82,000');
    expect(formatPrice(-12.35), '-₦12.35');
  });

  test('cart subtotal retains fractional product prices', () {
    const product = Product(
      id: 'fractional',
      name: 'Fractional-price product',
      vendorName: 'Test Store',
      unit: 'each',
      price: 10.25,
      color: Colors.green,
      icon: Icons.shopping_bag,
    );
    final cart = CartModel()..add(product, qty: 2);

    expect(cart.subtotal, 20.5);
    expect(formatPrice(cart.subtotal), '₦20.50');
  });
}
