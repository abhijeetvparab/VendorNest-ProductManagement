import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../models/product.dart';
import '../../models/vendor_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/vendor_provider.dart';
import '../vendor/products/add_edit_product_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  VendorProfile? _selectedVendor;

  // Vendor picker state
  String _vendorSearch  = '';
  String _pincodeSearch = '';
  final  _vendorSearchCtrl  = TextEditingController();
  final  _pincodeSearchCtrl = TextEditingController();

  // Product list state
  bool   _showDeleted = false;
  String _productSearch = '';
  final  _productSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVendors());
  }

  @override
  void dispose() {
    _vendorSearchCtrl.dispose();
    _pincodeSearchCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVendors() async {
    await context.read<VendorProvider>().loadApprovedVendors();
  }

  Future<void> _loadProducts() async {
    if (_selectedVendor == null) return;
    final token = context.read<AuthProvider>().accessToken!;
    await context.read<ProductProvider>().loadProducts(
          token,
          includeDeleted: _showDeleted,
          vendorId: _selectedVendor!.userId,
        );
  }

  void _selectVendor(VendorProfile v) {
    setState(() {
      _selectedVendor = v;
      _productSearch = '';
      _productSearchCtrl.clear();
    });
    _loadProducts();
  }

  void _clearVendor() {
    setState(() {
      _selectedVendor = null;
      _productSearch = '';
      _productSearchCtrl.clear();
      _vendorSearch = '';
      _vendorSearchCtrl.clear();
      _pincodeSearch = '';
      _pincodeSearchCtrl.clear();
    });
    context.read<ProductProvider>().clearError();
  }

  Future<void> _openEdit(Product p) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditProductScreen(product: p)),
    );
    if (result == true) _loadProducts();
  }

  List<VendorProfile> get _filteredVendors {
    final vendors = context.read<VendorProvider>().approvedVendors;
    final q   = _vendorSearch.toLowerCase();
    final pin = _pincodeSearch.trim().toLowerCase();
    return vendors.where((v) {
      final matchPin = pin.isEmpty ||
          (v.pincode?.toLowerCase().contains(pin) ?? false) ||
          v.businessAddress.toLowerCase().contains(pin);
      final matchSearch = q.isEmpty ||
          v.businessName.toLowerCase().contains(q) ||
          v.businessType.toLowerCase().contains(q) ||
          v.pocName.toLowerCase().contains(q);
      return matchPin && matchSearch;
    }).toList();
  }

  List<Product> get _filteredProducts {
    var products = context.read<ProductProvider>().products;
    if (_showDeleted) {
      products = products.where((p) => p.isDeleted).toList();
    }
    final q = _productSearch.toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.description?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: _selectedVendor == null
            ? const Text('Products — Select Vendor',
                style: TextStyle(fontWeight: FontWeight.w800))
            : Row(children: [
                InkWell(
                  onTap: _clearVendor,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.arrow_back_ios_new, size: 14,
                          color: Color(0xFF6B7280)),
                      SizedBox(width: 4),
                      Text('Vendors',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_selectedVendor!.businessName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed:
                _selectedVendor == null ? _loadVendors : _loadProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _selectedVendor == null
          ? _VendorPickerBody(
              searchCtrl: _vendorSearchCtrl,
              searchQuery: _vendorSearch,
              onSearchChanged: (v) => setState(() => _vendorSearch = v),
              pincodeCtrl: _pincodeSearchCtrl,
              pincodeQuery: _pincodeSearch,
              onPincodeChanged: (v) => setState(() => _pincodeSearch = v),
              filteredVendors: _filteredVendors,
              loading: context.watch<VendorProvider>().loading,
              onSelect: _selectVendor,
            )
          : _ProductListBody(
              searchCtrl: _productSearchCtrl,
              searchQuery: _productSearch,
              onSearchChanged: (v) => setState(() => _productSearch = v),
              showDeleted: _showDeleted,
              onToggleDeleted: (v) {
                setState(() => _showDeleted = v);
                _loadProducts();
              },
              filteredProducts: _filteredProducts,
              loading: context.watch<ProductProvider>().loading,
              onRefresh: _loadProducts,
              onEdit: _openEdit,
            ),
    );
  }
}

// ── Vendor Picker ─────────────────────────────────────────────────────────────
class _VendorPickerBody extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final void Function(String) onSearchChanged;
  final TextEditingController pincodeCtrl;
  final String pincodeQuery;
  final void Function(String) onPincodeChanged;
  final List<VendorProfile> filteredVendors;
  final bool loading;
  final void Function(VendorProfile) onSelect;

  const _VendorPickerBody({
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.pincodeCtrl,
    required this.pincodeQuery,
    required this.onPincodeChanged,
    required this.filteredVendors,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, type…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearchChanged('');
                        })
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: TextField(
              controller: pincodeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'Pin code',
                prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18),
                suffixIcon: pincodeQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          pincodeCtrl.clear();
                          onPincodeChanged('');
                        })
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
                counterText: '',
              ),
              onChanged: onPincodeChanged,
            ),
          ),
        ]),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : filteredVendors.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.storefront_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No vendors found',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280))),
                    ]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredVendors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _VendorCard(
                      vendor: filteredVendors[i],
                      onTap: () => onSelect(filteredVendors[i]),
                    ),
                  ),
      ),
    ]);
  }
}

class _VendorCard extends StatelessWidget {
  final VendorProfile vendor;
  final VoidCallback onTap;

  const _VendorCard({required this.vendor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                vendor.businessName.isNotEmpty
                    ? vendor.businessName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vendor.businessName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.violet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(vendor.businessType,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.violet,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(vendor.pocName,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  if (vendor.businessAddress.isNotEmpty || vendor.pincode != null) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(vendor.businessAddress,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (vendor.pincode != null && vendor.pincode!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(vendor.pincode!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF374151),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                  ],
                ]),
          ),
          const Icon(Icons.chevron_right,
              color: Color(0xFF9CA3AF), size: 20),
        ]),
      ),
    );
  }
}

// ── Product List (after vendor selected) ─────────────────────────────────────
class _ProductListBody extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final void Function(String) onSearchChanged;
  final bool showDeleted;
  final void Function(bool) onToggleDeleted;
  final List<Product> filteredProducts;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(Product) onEdit;

  const _ProductListBody({
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showDeleted,
    required this.onToggleDeleted,
    required this.filteredProducts,
    required this.loading,
    required this.onRefresh,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search products…',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged('');
                      })
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Show deleted',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(width: 6),
            Switch(
              value: showDeleted,
              onChanged: onToggleDeleted,
              activeThumbColor: AppTheme.rose,
            ),
          ]),
        ]),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : filteredProducts.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No products found',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      const Text('This vendor has no products yet',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF))),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _AdminProductCard(
                        product: filteredProducts[i],
                        onEdit: () => onEdit(filteredProducts[i]),
                      ),
                    ),
                  ),
      ),
    ]);
  }
}

// ── Product Card ──────────────────────────────────────────────────────────────
class _AdminProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;

  const _AdminProductCard({required this.product, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isDeleted = product.isDeleted;
    return Opacity(
      opacity: isDeleted ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDeleted ? Colors.red.shade100 : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isDeleted
                  ? Colors.grey.shade100
                  : AppTheme.violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_outlined,
                color: isDeleted ? Colors.grey : AppTheme.violet, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(product.name,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDeleted
                                  ? Colors.grey
                                  : const Color(0xFF1F2937)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isDeleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('Deleted',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  if (product.description != null &&
                      product.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(product.description!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _chip(product.unit, const Color(0xFF6366F1)),
                    if (product.isAvailable)
                      _chip('Available', Colors.green)
                    else
                      _chip('Unavailable', Colors.orange),
                    if (product.isSubscribable)
                      _chip('Subscribable', AppTheme.violet),
                  ]),
                  const SizedBox(height: 6),
                  Text('Updated ${product.updatedAt}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                ]),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            color: AppTheme.violet,
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}
