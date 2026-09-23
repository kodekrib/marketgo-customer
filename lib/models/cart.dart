import 'package:flutter/foundation.dart';
import 'marketplace.dart';

class CartItem {
  CartItem(this.product, this.quantity);

  final Product product;
  int quantity;
}

/// Shared shopping cart state.
///
/// A single [ChangeNotifier] owned by the app shell so the cart badge, the
/// storefront "add" buttons and the cart tab all read from the same source
/// of truth (DRY): no duplicated cart logic across screens.
class CartModel extends ChangeNotifier {
  final List<CartItem> _items = <CartItem>[];

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get quantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);
  int get subtotal =>
      _items.fold(0, (sum, item) => sum + item.product.price * item.quantity);

  int quantityOf(String productId) {
    for (final item in _items) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }

  void add(Product product, {int qty = 1}) {
    for (final item in _items) {
      if (item.product.id == product.id) {
        item.quantity += qty;
        notifyListeners();
        return;
      }
    }
    _items.add(CartItem(product, qty));
    notifyListeners();
  }

  void increment(Product product) => add(product, qty: 1);

  void decrement(Product product) {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].product.id == product.id) {
        if (_items[i].quantity > 1) {
          _items[i].quantity--;
        } else {
          _items.removeAt(i);
        }
        notifyListeners();
        return;
      }
    }
  }

  void removeProduct(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}