import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendorapp/providers/product_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _productJson({
  String id   = 'prod-1',
  String name = 'Tomatoes',
  String unit = 'kg',
  bool isDeleted = false,
}) =>
    {
      'id':              id,
      'vendor_id':       'vendor-1',
      'name':            name,
      'description':     null,
      'unit':            unit,
      'is_available':    true,
      'is_subscribable': false,
      'is_deleted':      isDeleted,
      'created_at':      '2024-03-15T10:00:00',
      'updated_at':      '2024-03-16T10:00:00',
    };

MockClient _mockClient(int status, dynamic body) => MockClient(
      (_) async => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      ),
    );

MockClient _mockNoContent() => MockClient(
      (_) async => http.Response('', 204,
          headers: {'content-type': 'application/json'}),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Initial state ──────────────────────────────────────────────────────────

  group('ProductProvider initial state', () {
    test('products list is empty', () {
      expect(ProductProvider().products, isEmpty);
    });

    test('loading is false', () {
      expect(ProductProvider().loading, false);
    });

    test('error is null', () {
      expect(ProductProvider().error, isNull);
    });
  });

  // ── loadProducts ───────────────────────────────────────────────────────────

  group('ProductProvider.loadProducts', () {
    test('populates products list on success', () async {
      final client   = _mockClient(200, [_productJson(id: 'p1'), _productJson(id: 'p2')]);
      final provider = ProductProvider();

      await http.runWithClient(() => provider.loadProducts('tok'), () => client);

      expect(provider.products.length, 2);
      expect(provider.products.first.id, 'p1');
    });

    test('maps product fields correctly', () async {
      final client   = _mockClient(200, [_productJson(id: 'p1', name: 'Carrots', unit: 'bunch')]);
      final provider = ProductProvider();

      await http.runWithClient(() => provider.loadProducts('tok'), () => client);

      final p = provider.products.first;
      expect(p.name, 'Carrots');
      expect(p.unit, 'bunch');
    });

    test('loading is false after success', () async {
      final client   = _mockClient(200, [_productJson()]);
      final provider = ProductProvider();

      await http.runWithClient(() => provider.loadProducts('tok'), () => client);

      expect(provider.loading, false);
    });

    test('sets error message on 403', () async {
      final client   = _mockClient(403, {'detail': 'Access denied'});
      final provider = ProductProvider();

      await http.runWithClient(() => provider.loadProducts('tok'), () => client);

      expect(provider.error, isNotNull);
      expect(provider.products, isEmpty);
    });

    test('loading is false after error', () async {
      final client   = _mockClient(403, {'detail': 'Access denied'});
      final provider = ProductProvider();

      await http.runWithClient(() => provider.loadProducts('tok'), () => client);

      expect(provider.loading, false);
    });

    test('replaces previous products on reload', () async {
      final provider = ProductProvider();

      final c1 = _mockClient(200, [_productJson(id: 'p1')]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => c1);
      expect(provider.products.length, 1);

      final c2 = _mockClient(200, [_productJson(id: 'p2'), _productJson(id: 'p3')]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => c2);
      expect(provider.products.length, 2);
      expect(provider.products.first.id, 'p2');
    });

    test('empty list returned when vendor has no products', () async {
      final client   = _mockClient(200, []);
      final provider = ProductProvider();

      await http.runWithClient(() => provider.loadProducts('tok'), () => client);

      expect(provider.products, isEmpty);
    });
  });

  // ── createProduct ──────────────────────────────────────────────────────────

  group('ProductProvider.createProduct', () {
    test('returns true on success', () async {
      final client   = _mockClient(201, _productJson(id: 'new-1'));
      final provider = ProductProvider();

      final result = await http.runWithClient(
        () => provider.createProduct('tok', {'name': 'Tomatoes', 'unit': 'kg'}),
        () => client,
      );

      expect(result, true);
    });

    test('inserts new product at index 0 of list', () async {
      final provider = ProductProvider();

      final cLoad = _mockClient(200, [_productJson(id: 'existing')]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => cLoad);

      final cCreate = _mockClient(201, _productJson(id: 'new-1', name: 'New Product'));
      await http.runWithClient(
        () => provider.createProduct('tok', {'name': 'New Product', 'unit': 'kg'}),
        () => cCreate,
      );

      expect(provider.products.first.id, 'new-1');
      expect(provider.products.length, 2);
    });

    test('returns false and sets error on 403', () async {
      final client   = _mockClient(403, {'detail': 'Only vendors can add products'});
      final provider = ProductProvider();

      final result = await http.runWithClient(
        () => provider.createProduct('tok', {'name': 'X', 'unit': 'kg'}),
        () => client,
      );

      expect(result, false);
      expect(provider.error, isNotNull);
    });

    test('returns false and sets error on 422 validation failure', () async {
      final client   = _mockClient(422, {'detail': 'Product name cannot be empty'});
      final provider = ProductProvider();

      final result = await http.runWithClient(
        () => provider.createProduct('tok', {'name': '', 'unit': 'kg'}),
        () => client,
      );

      expect(result, false);
      expect(provider.error, isNotNull);
    });

    test('loading is false after success', () async {
      final client   = _mockClient(201, _productJson());
      final provider = ProductProvider();

      await http.runWithClient(
        () => provider.createProduct('tok', {'name': 'T', 'unit': 'kg'}),
        () => client,
      );

      expect(provider.loading, false);
    });

    test('loading is false after error', () async {
      final client   = _mockClient(403, {'detail': 'Forbidden'});
      final provider = ProductProvider();

      await http.runWithClient(
        () => provider.createProduct('tok', {'name': 'T', 'unit': 'kg'}),
        () => client,
      );

      expect(provider.loading, false);
    });
  });

  // ── updateProduct ──────────────────────────────────────────────────────────

  group('ProductProvider.updateProduct', () {
    test('returns true on success', () async {
      final provider = ProductProvider();

      final cLoad = _mockClient(200, [_productJson(id: 'p1', name: 'Old Name')]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => cLoad);

      final cUpdate = _mockClient(200, _productJson(id: 'p1', name: 'New Name'));
      final result  = await http.runWithClient(
        () => provider.updateProduct('tok', 'p1', {'name': 'New Name'}),
        () => cUpdate,
      );

      expect(result, true);
    });

    test('updates product in list in-place', () async {
      final provider = ProductProvider();

      final cLoad = _mockClient(200, [_productJson(id: 'p1', name: 'Old')]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => cLoad);

      final cUpdate = _mockClient(200, _productJson(id: 'p1', name: 'Updated'));
      await http.runWithClient(
        () => provider.updateProduct('tok', 'p1', {'name': 'Updated'}),
        () => cUpdate,
      );

      expect(provider.products.first.name, 'Updated');
      expect(provider.products.length, 1);
    });

    test('returns false and sets error on 403', () async {
      final client   = _mockClient(403, {'detail': 'Access denied'});
      final provider = ProductProvider();

      final result = await http.runWithClient(
        () => provider.updateProduct('tok', 'p1', {'name': 'X'}),
        () => client,
      );

      expect(result, false);
      expect(provider.error, isNotNull);
    });

    test('returns false and sets error on 404', () async {
      final client   = _mockClient(404, {'detail': 'Product not found'});
      final provider = ProductProvider();

      final result = await http.runWithClient(
        () => provider.updateProduct('tok', 'bad-id', {'name': 'X'}),
        () => client,
      );

      expect(result, false);
      expect(provider.error, contains('not found'));
    });

    test('loading is false after success', () async {
      final client   = _mockClient(200, _productJson(id: 'p1'));
      final provider = ProductProvider();

      await http.runWithClient(
        () => provider.updateProduct('tok', 'p1', {'name': 'X'}),
        () => client,
      );

      expect(provider.loading, false);
    });

    test('loading is false after error', () async {
      final client   = _mockClient(404, {'detail': 'Product not found'});
      final provider = ProductProvider();

      await http.runWithClient(
        () => provider.updateProduct('tok', 'bad-id', {'name': 'X'}),
        () => client,
      );

      expect(provider.loading, false);
    });
  });

  // ── softDeleteProduct ──────────────────────────────────────────────────────

  group('ProductProvider.softDeleteProduct', () {
    test('returns true on 204 success', () async {
      final provider = ProductProvider();

      final cLoad = _mockClient(200, [_productJson(id: 'p1')]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => cLoad);

      final result = await http.runWithClient(
        () => provider.softDeleteProduct('tok', 'p1'),
        _mockNoContent,
      );

      expect(result, true);
    });

    test('removes product from list on success', () async {
      final provider = ProductProvider();

      final cLoad = _mockClient(200, [_productJson(id: 'p1'), _productJson(id: 'p2')]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => cLoad);
      expect(provider.products.length, 2);

      await http.runWithClient(
        () => provider.softDeleteProduct('tok', 'p1'),
        _mockNoContent,
      );

      expect(provider.products.length, 1);
      expect(provider.products.first.id, 'p2');
    });

    test('does not remove other products when deleting one', () async {
      final provider = ProductProvider();

      final cLoad = _mockClient(200, [
        _productJson(id: 'p1'),
        _productJson(id: 'p2'),
        _productJson(id: 'p3'),
      ]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => cLoad);

      await http.runWithClient(
        () => provider.softDeleteProduct('tok', 'p2'),
        _mockNoContent,
      );

      expect(provider.products.length, 2);
      expect(provider.products.any((p) => p.id == 'p1'), true);
      expect(provider.products.any((p) => p.id == 'p3'), true);
    });

    test('returns false and sets error on 403', () async {
      final client   = _mockClient(403, {'detail': 'Access denied'});
      final provider = ProductProvider();

      final result = await http.runWithClient(
        () => provider.softDeleteProduct('tok', 'p1'),
        () => client,
      );

      expect(result, false);
      expect(provider.error, isNotNull);
    });

    test('returns false and sets error on 404', () async {
      final client   = _mockClient(404, {'detail': 'Product not found'});
      final provider = ProductProvider();

      final result = await http.runWithClient(
        () => provider.softDeleteProduct('tok', 'bad-id'),
        () => client,
      );

      expect(result, false);
      expect(provider.error, contains('not found'));
    });

    test('loading is false after success', () async {
      final provider = ProductProvider();

      final cLoad = _mockClient(200, [_productJson(id: 'p1')]);
      await http.runWithClient(() => provider.loadProducts('tok'), () => cLoad);

      await http.runWithClient(
        () => provider.softDeleteProduct('tok', 'p1'),
        _mockNoContent,
      );

      expect(provider.loading, false);
    });

    test('loading is false after error', () async {
      final client   = _mockClient(403, {'detail': 'Access denied'});
      final provider = ProductProvider();

      await http.runWithClient(
        () => provider.softDeleteProduct('tok', 'p1'),
        () => client,
      );

      expect(provider.loading, false);
    });
  });

  // ── clearError ─────────────────────────────────────────────────────────────

  group('ProductProvider.clearError', () {
    test('resets error to null after a failed load', () async {
      final client   = _mockClient(403, {'detail': 'Access denied'});
      final provider = ProductProvider();

      await http.runWithClient(() => provider.loadProducts('tok'), () => client);
      expect(provider.error, isNotNull);

      provider.clearError();

      expect(provider.error, isNull);
    });

    test('resets error to null after a failed create', () async {
      final client   = _mockClient(403, {'detail': 'Only vendors can add products'});
      final provider = ProductProvider();

      await http.runWithClient(
        () => provider.createProduct('tok', {'name': 'X', 'unit': 'kg'}),
        () => client,
      );
      expect(provider.error, isNotNull);

      provider.clearError();

      expect(provider.error, isNull);
    });
  });
}
