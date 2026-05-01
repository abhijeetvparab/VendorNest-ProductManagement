import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_theme.dart';
import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../widgets/gradient_button.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Add mode: multiple units → one product per unit
  List<String> _selectedUnits = [];
  // Edit mode: single unit
  String? _editUnit;

  bool _isAvailable    = true;
  bool _isSubscribable = false;

  bool get _isEdit => widget.product != null;

  static const List<String> _suggestedUnits = [
    '100 G', '250 G', '500 G', '1 Kg', '2 Kg', '5 Kg',
    '100 ML', '250 ML', '500 ML', '1 Ltr', '2 Ltr', '5 Ltr',
    '1 Piece', '6 Pack', '12 Pack', '1 Dozen', '1 Box', '1 Set',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text  = p.name;
      _descCtrl.text  = p.description ?? '';
      _editUnit       = p.unit;
      _isAvailable    = p.isAvailable;
      _isSubscribable = p.isSubscribable;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUnitPickerDialog() async {
    final tempSelected = List<String>.from(_selectedUnits);
    final customCtrl   = TextEditingController();
    final allUnits     = List<String>.from(_suggestedUnits);
    for (final u in tempSelected) {
      if (!allUnits.contains(u)) allUnits.add(u);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Select Available Units',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: allUnits.length,
                    itemBuilder: (_, i) {
                      final u = allUnits[i];
                      return CheckboxListTile(
                        value: tempSelected.contains(u),
                        title: Text(u, style: const TextStyle(fontSize: 14)),
                        activeColor: AppTheme.violet,
                        dense: true,
                        onChanged: (v) => setDialogState(() {
                          if (v == true) {
                            tempSelected.add(u);
                          } else {
                            tempSelected.remove(u);
                          }
                        }),
                      );
                    },
                  ),
                ),
                const Divider(height: 16),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: customCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Custom unit (e.g. 750 ML)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final v = customCtrl.text.trim();
                      if (v.isEmpty) return;
                      setDialogState(() {
                        if (!allUnits.contains(v)) allUnits.add(v);
                        if (!tempSelected.contains(v)) tempSelected.add(v);
                        customCtrl.clear();
                      });
                    },
                    child: const Text('Add'),
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedUnits = List<String>.from(tempSelected));
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final token    = context.read<AuthProvider>().accessToken!;
    final provider = context.read<ProductProvider>();

    if (_isEdit) {
      if (_editUnit == null || _editUnit!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a unit'),
          backgroundColor: AppTheme.rose,
        ));
        return;
      }
      final ok = await provider.updateProduct(token, widget.product!.id, {
        'name':            _nameCtrl.text.trim(),
        'description':     _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'unit':            _editUnit,
        'is_available':    _isAvailable,
        'is_subscribable': _isSubscribable,
      });
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.error ?? 'Failed to save product'),
          backgroundColor: AppTheme.rose,
        ));
      }
    } else {
      if (_selectedUnits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select at least one unit'),
          backgroundColor: AppTheme.rose,
        ));
        return;
      }
      bool anyFailed = false;
      for (final unit in _selectedUnits) {
        final ok = await provider.createProduct(token, {
          'name':            _nameCtrl.text.trim(),
          'description':     _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'unit':            unit,
          'is_available':    _isAvailable,
          'is_subscribable': _isSubscribable,
        });
        if (!ok) anyFailed = true;
      }
      if (!mounted) return;
      if (!anyFailed) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.error ?? 'Failed to create some products'),
          backgroundColor: AppTheme.rose,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<ProductProvider>().loading;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Product' : 'Add Product',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionCard(
                    title: 'Product Details',
                    icon: Icons.inventory_2_outlined,
                    children: [
                      _field(
                        controller: _nameCtrl,
                        label: 'Product Name',
                        icon: Icons.label_outline,
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _descCtrl,
                        label: 'Description (optional)',
                        icon: Icons.notes_outlined,
                        maxLines: 3,
                        validator: (v) {
                          if (v != null && v.trim().length > 500) {
                            return 'Max 500 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildUnitsSection(),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Availability & Subscription',
                    icon: Icons.toggle_on_outlined,
                    children: [
                      _toggleTile(
                        title: 'Available',
                        subtitle: 'Product is currently in stock / offered',
                        value: _isAvailable,
                        activeColor: AppTheme.emerald,
                        onChanged: (v) => setState(() => _isAvailable = v),
                      ),
                      const Divider(height: 20, color: Color(0xFFE5E7EB)),
                      _toggleTile(
                        title: 'Subscribable',
                        subtitle: 'Customers can subscribe to this product',
                        value: _isSubscribable,
                        activeColor: AppTheme.violet,
                        onChanged: (v) => setState(() => _isSubscribable = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  GradientButton(
                    label: _isEdit ? 'Save Changes' : 'Add Product',
                    loading: loading,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitsSection() {
    if (_isEdit) {
      final allUnits = List<String>.from(_suggestedUnits);
      if (_editUnit != null && !allUnits.contains(_editUnit)) {
        allUnits.insert(0, _editUnit!);
      }
      return _sectionCard(
        title: 'Available Unit',
        icon: Icons.straighten_outlined,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _editUnit,
            decoration: const InputDecoration(
              labelText: 'Unit *',
              prefixIcon: Icon(Icons.straighten_outlined),
            ),
            items: allUnits
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _editUnit = v),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.straighten_outlined, size: 16, color: AppTheme.violet),
          const SizedBox(width: 8),
          const Text('Available Units',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151))),
          const Spacer(),
          if (_selectedUnits.isNotEmpty)
            Text('${_selectedUnits.length} selected',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.violet,
                    fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        const Text(
          'One product will be created for each selected unit',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openUnitPickerDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF9FAFB),
            ),
            child: Row(children: [
              const Icon(Icons.checklist_outlined,
                  size: 18, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedUnits.isEmpty
                      ? 'Tap to select units…'
                      : _selectedUnits.join(', '),
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedUnits.isEmpty
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
            ]),
          ),
        ),
        if (_selectedUnits.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _selectedUnits
                .map((u) => Chip(
                      label: Text(u,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      backgroundColor: AppTheme.violet,
                      deleteIconColor: Colors.white70,
                      onDeleted: () =>
                          setState(() => _selectedUnits.remove(u)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 6),
                    ))
                .toList(),
          ),
        ],
      ]),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: AppTheme.violet),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151))),
          ]),
          const SizedBox(height: 16),
          ...children,
        ]),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: validator,
      );

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required void Function(bool) onChanged,
  }) =>
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeColor,
        ),
      ]);
}
