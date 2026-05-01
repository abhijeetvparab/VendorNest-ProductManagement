import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_theme.dart';
import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/product_provider.dart';
import 'add_edit_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  bool   _showDeleted  = false;
  String _searchQuery  = '';
  final  _searchCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().accessToken!;
    await context.read<ProductProvider>().loadProducts(token, includeDeleted: _showDeleted);
  }

  Future<void> _delete(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${p.name}"? This can be undone by an admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = context.read<AuthProvider>().accessToken!;
    final ok = await context.read<ProductProvider>().softDeleteProduct(token, p.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<ProductProvider>().error ?? 'Failed to delete'),
        backgroundColor: AppTheme.rose,
      ));
    }
  }

  Future<void> _openAddEdit([Product? p]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditProductScreen(product: p)),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Products',
            style: TextStyle(fontWeight: FontWeight.w800)),
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
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEdit(),
        backgroundColor: AppTheme.violet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _FilterBar(
            searchCtrl: _searchCtrl,
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            showDeleted: _showDeleted,
            onToggleDeleted: (v) {
              setState(() => _showDeleted = v);
              _load();
            },
          ),
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : Builder(builder: (context) {
                    var products = _showDeleted
                        ? provider.products.where((p) => p.isDeleted).toList()
                        : provider.products;
                    final q = _searchQuery.trim().toLowerCase();
                    if (q.isNotEmpty) {
                      products = products.where((p) =>
                          p.name.toLowerCase().contains(q) ||
                          p.unit.toLowerCase().contains(q)).toList();
                    }
                    if (products.isEmpty) return _EmptyState(onAdd: () => _openAddEdit());
                    return RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ProductCard(
                          product: products[i],
                          onEdit: () => _openAddEdit(products[i]),
                          onDelete: () => _delete(products[i]),
                        ),
                      ),
                    );
                  }),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final void Function(String) onSearchChanged;
  final bool showDeleted;
  final void Function(bool) onToggleDeleted;

  const _FilterBar({
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showDeleted,
    required this.onToggleDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by name or unit…',
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
        const SizedBox(height: 8),
        Row(children: [
          const Text('Show deleted',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const Spacer(),
          Switch(
            value: showDeleted,
            onChanged: onToggleDeleted,
            activeThumbColor: AppTheme.violet,
          ),
        ]),
      ]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = product.isDeleted;
    return Opacity(
      opacity: isDeleted ? 0.55 : 1.0,
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
                blurRadius: 8, offset: const Offset(0, 2)),
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
            child: Icon(
              Icons.inventory_2_outlined,
              color: isDeleted ? Colors.grey : AppTheme.violet,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(product.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDeleted ? Colors.grey : const Color(0xFF1F2937)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (isDeleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Deleted',
                        style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
              ]),
              if (product.description != null && product.description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(product.description!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _chip(product.unit, AppTheme.violet),
                if (product.isAvailable)
                  _chip('Available', Colors.green)
                else
                  _chip('Unavailable', Colors.orange),
                if (product.isSubscribable) _chip('Subscribable', AppTheme.violet),
              ]),
            ]),
          ),
          if (!isDeleted) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
              color: AppTheme.violet,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
              color: AppTheme.rose,
              visualDensity: VisualDensity.compact,
            ),
          ],
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
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('No products yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        const Text('Add your first product to get started',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add Product'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
        ),
      ]),
    );
  }
}
