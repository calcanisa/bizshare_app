import 'package:flutter/foundation.dart';

class CartItem {
  final String id;
  final String title;
  final double price;
  final String type;
  final String? image;
  final String? contentType;
  final int? contentId;
  final String? memType;
  final bool? feature;
  final List<String>? featureTypes;

  CartItem({
    required this.id,
    required this.title,
    required this.price,
    required this.type,
    this.image,
    this.contentType,
    this.contentId,
    this.memType,
    this.feature,
    this.featureTypes,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'amount': price,
        'content_type': contentType,
        'content_id': contentId,
        'mem_type': memType,
        'quantity': 1,
        'feature': feature,
        'feature_types': featureTypes,
      };
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  double get subtotal => _items.fold(0, (sum, item) => sum + item.price);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get onlyVerification =>
      _items.isNotEmpty && _items.every((i) => i.type == 'verification');

  void addItem(CartItem item) {
    if (_items.any((i) => i.id == item.id)) return;
    _items.add(item);
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
