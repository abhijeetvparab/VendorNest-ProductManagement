import 'package:flutter_test/flutter_test.dart';
import 'package:vendorapp/models/product.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _productJson({
  String  id             = 'prod-123',
  String  vendorId       = 'vendor-456',
  String  name           = 'Fresh Tomatoes',
  String? description    = 'Locally sourced tomatoes',
  String  unit           = 'kg',
  bool    isAvailable    = true,
  bool    isSubscribable = false,
  bool    isDeleted      = false,
  String  createdAt      = '2024-03-15T10:00:00',
  String  updatedAt      = '2024-03-16T12:30:45',
}) =>
    {
      'id':              id,
      'vendor_id':       vendorId,
      'name':            name,
      'description':     description,
      'unit':            unit,
      'is_available':    isAvailable,
      'is_subscribable': isSubscribable,
      'is_deleted':      isDeleted,
      'created_at':      createdAt,
      'updated_at':      updatedAt,
    };

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── fromJson ──────────────────────────────────────────────────────────────

  group('Product.fromJson', () {
    test('parses id correctly', () {
      expect(Product.fromJson(_productJson()).id, 'prod-123');
    });

    test('parses vendorId from vendor_id key', () {
      expect(Product.fromJson(_productJson()).vendorId, 'vendor-456');
    });

    test('parses name correctly', () {
      expect(Product.fromJson(_productJson()).name, 'Fresh Tomatoes');
    });

    test('parses unit correctly', () {
      expect(Product.fromJson(_productJson()).unit, 'kg');
    });

    test('parses description when present', () {
      final p = Product.fromJson(_productJson(description: 'Some description'));
      expect(p.description, 'Some description');
    });

    test('parses null description', () {
      final p = Product.fromJson(_productJson(description: null));
      expect(p.description, isNull);
    });

    test('truncates createdAt to date-only string', () {
      final p = Product.fromJson(_productJson(createdAt: '2024-03-15T10:00:00'));
      expect(p.createdAt, '2024-03-15');
    });

    test('truncates updatedAt to date-only string', () {
      final p = Product.fromJson(_productJson(updatedAt: '2024-03-16T12:30:45'));
      expect(p.updatedAt, '2024-03-16');
    });

    test('parses isAvailable true', () {
      expect(Product.fromJson(_productJson(isAvailable: true)).isAvailable, true);
    });

    test('parses isAvailable false', () {
      expect(Product.fromJson(_productJson(isAvailable: false)).isAvailable, false);
    });

    test('parses isSubscribable true', () {
      expect(Product.fromJson(_productJson(isSubscribable: true)).isSubscribable, true);
    });

    test('parses isSubscribable false', () {
      expect(Product.fromJson(_productJson(isSubscribable: false)).isSubscribable, false);
    });

    test('parses isDeleted false for active product', () {
      expect(Product.fromJson(_productJson(isDeleted: false)).isDeleted, false);
    });

    test('parses isDeleted true for soft-deleted product', () {
      expect(Product.fromJson(_productJson(isDeleted: true)).isDeleted, true);
    });
  });

  // ── toJson ────────────────────────────────────────────────────────────────

  group('Product.toJson', () {
    test('serialises id correctly', () {
      expect(Product.fromJson(_productJson()).toJson()['id'], 'prod-123');
    });

    test('serialises vendor_id from vendorId field', () {
      expect(Product.fromJson(_productJson()).toJson()['vendor_id'], 'vendor-456');
    });

    test('serialises name correctly', () {
      expect(Product.fromJson(_productJson()).toJson()['name'], 'Fresh Tomatoes');
    });

    test('serialises unit correctly', () {
      expect(Product.fromJson(_productJson()).toJson()['unit'], 'kg');
    });

    test('serialises description when present', () {
      final json = Product.fromJson(_productJson(description: 'A desc')).toJson();
      expect(json['description'], 'A desc');
    });

    test('serialises null description as null', () {
      final json = Product.fromJson(_productJson(description: null)).toJson();
      expect(json['description'], isNull);
    });

    test('serialises is_available correctly', () {
      expect(Product.fromJson(_productJson(isAvailable: false)).toJson()['is_available'], false);
    });

    test('serialises is_subscribable correctly', () {
      expect(Product.fromJson(_productJson(isSubscribable: true)).toJson()['is_subscribable'], true);
    });

    test('serialises is_deleted correctly', () {
      expect(Product.fromJson(_productJson(isDeleted: true)).toJson()['is_deleted'], true);
    });

    test('round-trips id through fromJson without data loss', () {
      final original     = Product.fromJson(_productJson());
      final roundTripped = Product.fromJson(original.toJson());
      expect(roundTripped.id,             original.id);
      expect(roundTripped.vendorId,       original.vendorId);
      expect(roundTripped.name,           original.name);
      expect(roundTripped.description,    original.description);
      expect(roundTripped.unit,           original.unit);
      expect(roundTripped.isAvailable,    original.isAvailable);
      expect(roundTripped.isSubscribable, original.isSubscribable);
      expect(roundTripped.isDeleted,      original.isDeleted);
      expect(roundTripped.createdAt,      original.createdAt);
      expect(roundTripped.updatedAt,      original.updatedAt);
    });
  });
}
