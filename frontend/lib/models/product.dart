class Product {
  final String  id;
  final String  vendorId;
  final String  name;
  final String? description;
  final String  unit;
  final bool    isAvailable;
  final bool    isSubscribable;
  final bool    isDeleted;
  final String  createdAt;
  final String  updatedAt;

  const Product({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    required this.unit,
    required this.isAvailable,
    required this.isSubscribable,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id:             json['id']              as String,
    vendorId:       json['vendor_id']       as String,
    name:           json['name']            as String,
    description:    json['description']     as String?,
    unit:           json['unit']            as String,
    isAvailable:    json['is_available']    as bool,
    isSubscribable: json['is_subscribable'] as bool,
    isDeleted:      json['is_deleted']      as bool,
    createdAt:      (json['created_at']     as String).substring(0, 10),
    updatedAt:      (json['updated_at']     as String).substring(0, 10),
  );

  Map<String, dynamic> toJson() => {
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
}
