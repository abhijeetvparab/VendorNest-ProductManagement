import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool    _loading = false;
  String? _error;

  List<Product> get products        => _products;
  bool          get loading         => _loading;
  String?       get error           => _error;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadProducts(
    String token, {
    bool    includeDeleted = false,
    String? vendorId,
  }) async {
    _setLoading(true);
    try {
      final query = <String, String>{};
      if (includeDeleted) query['include_deleted'] = 'true';
      if (vendorId != null && vendorId.isNotEmpty) query['vendor_id'] = vendorId;
      final data = await ApiService.get(ApiConfig.products, token: token, query: query);
      _products = (data as List).map((e) => Product.fromJson(e)).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _setLoading(false);
    }
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<bool> createProduct(String token, Map<String, dynamic> payload) async {
    _setLoading(true);
    try {
      final data = await ApiService.post(ApiConfig.products, payload, token: token);
      _products.insert(0, Product.fromJson(data));
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<bool> updateProduct(
      String token, String id, Map<String, dynamic> payload) async {
    _setLoading(true);
    try {
      final data = await ApiService.patch(
          ApiConfig.productById(id), payload, token: token);
      final updated = Product.fromJson(data);
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx >= 0) _products[idx] = updated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Soft Delete ───────────────────────────────────────────────────────────

  Future<bool> softDeleteProduct(String token, String id) async {
    _setLoading(true);
    try {
      await ApiService.delete(ApiConfig.productById(id), token: token);
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() { _error = null; notifyListeners(); }
  void _setLoading(bool v) { _loading = v; notifyListeners(); }
}
