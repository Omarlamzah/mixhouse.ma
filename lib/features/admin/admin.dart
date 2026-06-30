part of '../../main.dart';

class AdminModulePage extends StatefulWidget {
  final Api api;
  final String title;
  final IconData icon;
  const AdminModulePage({
    required this.api,
    required this.title,
    required this.icon,
    super.key,
  });
  @override
  State<AdminModulePage> createState() => _AdminModulePageState();
}

class _PickedImagePreview extends StatelessWidget {
  final XFile file;
  final double height;
  const _PickedImagePreview({required this.file, required this.height});
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: file.readAsBytes(),
    builder: (context, snapshot) => snapshot.hasData
        ? Image.memory(
            snapshot.data!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
          )
        : SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          ),
  );
}

class SettingsPage extends StatefulWidget {
  final Api api;
  const SettingsPage({required this.api, super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, String> form = {};
  bool loading = true, saving = false;
  XFile? logo, cover;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await widget.api.request('/admin/settings');
      if (mounted) {
        setState(() {
          form = Map<String, String>.fromEntries(
            (response as Map).entries.map(
              (e) => MapEntry('${e.key}', '${e.value ?? ''}'),
            ),
          );
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget field(
    String key,
    String label, {
    TextInputType? keyboard,
    int lines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('$key-${form[key]}'),
      initialValue: form[key] ?? '',
      keyboardType: keyboard,
      maxLines: lines,
      onChanged: (v) => form[key] = v,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
  Widget toggle(String key, String label) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    value: form[key] != '0',
    onChanged: (v) => setState(() => form[key] = v ? '1' : '0'),
  );
  Widget section(String title, List<Widget> children) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 18),
      ...children,
      const SizedBox(height: 70),
    ],
  );
  Future<void> save() async {
    setState(() => saving = true);
    try {
      final allowed = [
        'restaurant_name',
        'restaurant_slug',
        'restaurant_description',
        'restaurant_address',
        'restaurant_phone',
        'google_maps_embed',
        'google_review_url',
        'instagram_url',
        'whatsapp_number',
        'receipt_logo',
        'receipt_name',
        'receipt_address',
        'receipt_phone',
        'receipt_whatsapp',
        'receipt_review_qr',
        'receipt_instagram',
        'loyalty_rate_dh',
        'loyalty_rate_pts',
        'loyalty_min_order',
        'loyalty_welcome_pts',
        'referral_referee_pts',
        'referral_referrer_pts',
        'desktop_pin',
      ];
      final fields = {
        for (final key in allowed)
          if (form.containsKey(key)) key: form[key]!,
      };
      final response = await widget.api.multipart(
        '/admin/settings',
        fields: fields,
        files: {'logo': logo, 'cover': cover},
      );
      if (mounted) {
        setState(() {
          form = Map<String, String>.fromEntries(
            (response as Map).entries.map(
              (e) => MapEntry('${e.key}', '${e.value ?? ''}'),
            ),
          );
          logo = null;
          cover = null;
          saving = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings saved.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget mediaPicker(
    String title,
    String urlKey,
    XFile? file,
    VoidCallback pick,
  ) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: file != null
                ? _PickedImagePreview(file: file, height: 180)
                : form[urlKey]?.isNotEmpty == true
                ? Image.network(
                    storageUrl(form[urlKey])!,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 120,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                  )
                : const SizedBox(
                    height: 120,
                    child: Icon(Icons.image_outlined, size: 42),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: pick,
            icon: const Icon(Icons.upload_outlined),
            label: Text('Choose $title'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      style: FilledButton.styleFrom(backgroundColor: orange),
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'General'),
                    Tab(text: 'Links'),
                    Tab(text: 'Media'),
                    Tab(text: 'Loyalty'),
                    Tab(text: 'Receipt'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                section('Restaurant identity', [
                  field('restaurant_name', 'Restaurant name'),
                  field('restaurant_slug', 'Menu URL slug'),
                  field('restaurant_description', 'Description', lines: 4),
                  field('restaurant_address', 'Address', lines: 2),
                  field(
                    'restaurant_phone',
                    'Phone',
                    keyboard: TextInputType.phone,
                  ),
                  field(
                    'desktop_pin',
                    'Desktop PIN',
                    keyboard: TextInputType.number,
                  ),
                ]),
                section('Online links', [
                  field(
                    'whatsapp_number',
                    'WhatsApp number',
                    keyboard: TextInputType.phone,
                  ),
                  field(
                    'google_review_url',
                    'Google review URL',
                    keyboard: TextInputType.url,
                  ),
                  field(
                    'instagram_url',
                    'Instagram URL',
                    keyboard: TextInputType.url,
                  ),
                  field(
                    'google_maps_embed',
                    'Google Maps embed URL',
                    keyboard: TextInputType.url,
                    lines: 3,
                  ),
                ]),
                section('Brand media', [
                  mediaPicker('logo', 'logo_url', logo, () async {
                    final x = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 90,
                      maxWidth: 1600,
                    );
                    if (x != null) setState(() => logo = x);
                  }),
                  mediaPicker('cover', 'cover_url', cover, () async {
                    final x = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 90,
                      maxWidth: 2200,
                    );
                    if (x != null) setState(() => cover = x);
                  }),
                ]),
                section('Customer loyalty', [
                  field(
                    'loyalty_min_order',
                    'Minimum order (DH)',
                    keyboard: TextInputType.number,
                  ),
                  field(
                    'loyalty_rate_dh',
                    'Spend amount for points (DH)',
                    keyboard: TextInputType.number,
                  ),
                  field(
                    'loyalty_rate_pts',
                    'Points earned per rate',
                    keyboard: TextInputType.number,
                  ),
                  field(
                    'loyalty_welcome_pts',
                    'Signup bonus points',
                    keyboard: TextInputType.number,
                  ),
                  field(
                    'referral_referee_pts',
                    'Referred customer points',
                    keyboard: TextInputType.number,
                  ),
                  field(
                    'referral_referrer_pts',
                    'Referrer points',
                    keyboard: TextInputType.number,
                  ),
                ]),
                section('Receipt content', [
                  toggle('receipt_logo', 'Show logo'),
                  toggle('receipt_name', 'Show restaurant name'),
                  toggle('receipt_address', 'Show address'),
                  toggle('receipt_phone', 'Show phone'),
                  toggle('receipt_whatsapp', 'Show WhatsApp'),
                  toggle('receipt_review_qr', 'Show review QR code'),
                  toggle('receipt_instagram', 'Show Instagram'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminModulePageState extends State<AdminModulePage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String search = '', error = '';

  String get endpoint {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return switch (widget.title) {
      'Orders' => '/admin/orders',
      'Charges' => '/admin/expenses',
      'Products' => '/products',
      'Categories' => '/categories',
      'Customers' => '/admin/customers',
      'Staff' => '/admin/staff',
      'Suppliers' => '/admin/suppliers',
      'Stock' => '/admin/stock',
      'Reports' => '/admin/reports/range?start_date=$today&end_date=$today',
      'Settings' => '/admin/settings',
      _ => '/admin/orders',
    };
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final response = await widget.api.request(endpoint);
      dynamic value = response is Map && response.containsKey('data')
          ? response['data']
          : response;
      final parsed = <Map<String, dynamic>>[];
      if (value is List) {
        parsed.addAll(
          value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      } else if (value is Map) {
        for (final entry in value.entries) {
          if (entry.value is Map) {
            parsed.add({
              'name': entry.key,
              ...Map<String, dynamic>.from(entry.value),
            });
          } else if (entry.value is! List) {
            parsed.add({'name': entry.key, 'value': entry.value});
          }
        }
      }
      if (mounted) {
        setState(() {
          rows = parsed;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
      }
    }
  }

  String primary(Map row) =>
      '${row['name'] ?? row['description'] ?? row['guest_name'] ?? row['restaurant_name'] ?? '${widget.title} #${row['id'] ?? ''}'}';
  String secondary(Map row) => switch (widget.title) {
    'Orders' =>
      '${row['order_type'] ?? 'eat_in'} • ${row['payment_method'] ?? 'cash'} • ${row['order_status'] ?? 'pending'}',
    'Charges' => '${row['category'] ?? ''} • ${row['payment_method'] ?? ''}',
    'Products' =>
      '${row['category']?['name'] ?? 'Product'} • ${row['is_available'] == false ? 'Unavailable' : 'Available'}',
    'Customers' =>
      '${row['phone'] ?? row['email'] ?? 'No contact'} • ${row['points'] ?? 0} points',
    'Staff' =>
      '${row['email'] ?? ''} • ${row['role'] ?? 'staff'} • ${row['status'] ?? 'pending'}',
    'Suppliers' =>
      '${row['phone'] ?? row['email'] ?? 'No contact'} • ${row['purchases_count'] ?? 0} purchases',
    'Stock' =>
      '${row['current_quantity'] ?? 0} ${row['unit'] ?? ''} • minimum ${row['min_quantity'] ?? 0}',
    _ =>
      row.entries
          .where((e) => e.key != 'name' && e.value != null)
          .take(2)
          .map((e) => '${e.key}: ${e.value}')
          .join(' • '),
  };
  String? trailing(Map row) => switch (widget.title) {
    'Orders' => '${row['total'] ?? '0.00'} DH',
    'Charges' => '${row['amount'] ?? '0.00'} DH',
    'Products' => '${row['price'] ?? '0.00'} DH',
    'Suppliers' => '${row['total_debt'] ?? '0.00'} DH debt',
    _ => null,
  };

  Future<void> approve(Map row) async {
    try {
      await widget.api.request(
        '/admin/staff/${row['id']}/approve',
        method: 'POST',
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  bool get supportsCrud =>
      const ['Charges', 'Products', 'Categories'].contains(widget.title);

  Future<void> editRow([Map<String, dynamic>? row]) async {
    if (widget.title == 'Products') return editProduct(row);
    if (widget.title == 'Categories') return editCategory(row);
    if (widget.title == 'Charges') return editCharge(row);
  }

  Future<void> editProduct(Map<String, dynamic>? row) async {
    final name = TextEditingController(text: '${row?['name'] ?? ''}');
    final price = TextEditingController(text: '${row?['price'] ?? ''}');
    final description = TextEditingController(
      text: '${row?['description'] ?? ''}',
    );
    var available = row?['is_available'] != false;
    XFile? selectedImage;
    List categories = [];
    try {
      final r = await widget.api.request('/categories');
      categories = r['data'] ?? [];
    } catch (_) {}
    int? categoryId = row?['category_id'] as int?;
    categoryId ??= categories.isEmpty ? null : categories.first['id'];
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(row == null ? 'New product' : 'Edit product'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedImage != null || row?['image_url'] != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: selectedImage != null
                          ? _PickedImagePreview(
                              file: selectedImage!,
                              height: 140,
                            )
                          : Image.network(
                              storageUrl(row!['image_url'])!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 88,
                        maxWidth: 1600,
                      );
                      if (picked != null) {
                        setDialog(() => selectedImage = picked);
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      selectedImage == null
                          ? 'Choose product image'
                          : 'Change image',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map<DropdownMenuItem<int>>(
                          (c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(c['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => categoryId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      suffixText: 'DH',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available in POS'),
                    value: available,
                    onChanged: (v) => setDialog(() => available = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true && name.text.trim().isNotEmpty && categoryId != null) {
      try {
        await widget.api.multipart(
          row == null ? '/admin/products' : '/admin/products/${row['id']}',
          update: row != null,
          fields: {
            'name': name.text.trim(),
            'category_id': '$categoryId',
            'price': '${double.tryParse(price.text) ?? 0}',
            'description': description.text.trim(),
            'is_available': available ? '1' : '0',
          },
          files: {'image': selectedImage},
        );
        await load();
      } catch (e) {
        showError(e);
      }
    }
    name.dispose();
    price.dispose();
    description.dispose();
  }

  Future<void> editCategory(Map<String, dynamic>? row) async {
    final name = TextEditingController(text: '${row?['name'] ?? ''}');
    final order = TextEditingController(text: '${row?['order'] ?? 0}');
    XFile? selectedImage;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(row == null ? 'New category' : 'Edit category'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedImage != null || row?['image_url'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: selectedImage != null
                        ? _PickedImagePreview(file: selectedImage!, height: 130)
                        : Image.network(
                            storageUrl(row!['image_url'])!,
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 88,
                      maxWidth: 1600,
                    );
                    if (picked != null) setDialog(() => selectedImage = picked);
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    selectedImage == null
                        ? 'Choose category image'
                        : 'Change image',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Category name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Display order'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true && name.text.trim().isNotEmpty) {
      try {
        await widget.api.multipart(
          row == null ? '/admin/categories' : '/admin/categories/${row['id']}',
          update: row != null,
          fields: {
            'name': name.text.trim(),
            'order': '${int.tryParse(order.text) ?? 0}',
          },
          files: {'image': selectedImage},
        );
        await load();
      } catch (e) {
        showError(e);
      }
    }
    name.dispose();
    order.dispose();
  }

  Future<void> editCharge(Map<String, dynamic>? row) async {
    final description = TextEditingController(
      text: '${row?['description'] ?? ''}',
    );
    final amount = TextEditingController(text: '${row?['amount'] ?? ''}');
    var category = '${row?['category'] ?? 'other'}',
        payment = '${row?['payment_method'] ?? 'cash'}';
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(row == null ? 'New charge' : 'Edit charge'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    suffixText: 'DH',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items:
                      const [
                            ('supplier', 'Supplier'),
                            ('utilities', 'Utilities'),
                            ('transport', 'Transport'),
                            ('maintenance', 'Maintenance'),
                            ('staff', 'Staff'),
                            ('other', 'Other'),
                          ]
                          .map(
                            (x) => DropdownMenuItem(
                              value: x.$1,
                              child: Text(x.$2),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setDialog(() => category = v!),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cash', label: Text('Cash')),
                    ButtonSegment(value: 'card', label: Text('Card')),
                  ],
                  selected: {payment},
                  onSelectionChanged: (v) => setDialog(() => payment = v.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true &&
        description.text.trim().isNotEmpty &&
        (double.tryParse(amount.text) ?? 0) > 0) {
      try {
        await widget.api.request(
          row == null ? '/expenses' : '/admin/expenses/${row['id']}',
          method: row == null ? 'POST' : 'PUT',
          body: {
            'description': description.text.trim(),
            'amount': double.parse(amount.text),
            'category': category,
            'payment_method': payment,
            if (row != null)
              'expense_date':
                  row['expense_date'] ??
                  DateTime.now().toIso8601String().substring(0, 10),
          },
        );
        await load();
      } catch (e) {
        showError(e);
      }
    }
    description.dispose();
    amount.dispose();
  }

  Future<void> deleteRow(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete “${primary(row)}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final path = switch (widget.title) {
      'Products' => '/admin/products/${row['id']}',
      'Categories' => '/admin/categories/${row['id']}',
      'Charges' => '/admin/expenses/${row['id']}',
      _ => '',
    };
    try {
      await widget.api.request(path, method: 'DELETE');
      await load();
    } catch (e) {
      showError(e);
    }
  }

  void showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget managementActions(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (trailing(row) != null)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            trailing(row)!,
            style: const TextStyle(fontWeight: FontWeight.w900, color: orange),
          ),
        ),
      PopupMenuButton<String>(
        tooltip: 'Manage',
        onSelected: (value) => value == 'edit' ? editRow(row) : deleteRow(row),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Delete'),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final filtered = rows
        .where(
          (row) =>
              primary(row).toLowerCase().contains(search.toLowerCase()) ||
              secondary(row).toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffffedd5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(widget.icon, color: orange),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (supportsCrud) ...[
                        FilledButton.icon(
                          onPressed: () => editRow(),
                          style: FilledButton.styleFrom(
                            backgroundColor: orange,
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(
                            MediaQuery.sizeOf(context).width < 520
                                ? 'Add'
                                : 'Add ${widget.title == 'Charges' ? 'charge' : widget.title.toLowerCase().substring(0, widget.title.length - 1)}',
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton.filledTonal(
                        onPressed: load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    onChanged: (value) => setState(() => search = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search ${widget.title.toLowerCase()}…',
                    ),
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 44, color: Colors.black26),
                    const SizedBox(height: 12),
                    Text(
                      'No ${widget.title.toLowerCase()} found',
                      style: const TextStyle(color: Colors.black45),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final row = filtered[i];
                  final low =
                      widget.title == 'Stock' &&
                      (double.tryParse('${row['current_quantity']}') ?? 0) <=
                          (double.tryParse('${row['min_quantity']}') ?? 0);
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: low
                            ? Colors.red.shade50
                            : const Color(0xfffff7ed),
                        child: Icon(
                          widget.icon,
                          color: low ? Colors.red : orange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        primary(row),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        secondary(row),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: supportsCrud ? () => editRow(row) : null,
                      trailing:
                          widget.title == 'Staff' && row['status'] != 'active'
                          ? FilledButton(
                              onPressed: () => approve(row),
                              child: const Text('Approve'),
                            )
                          : supportsCrud
                          ? managementActions(row)
                          : trailing(row) == null
                          ? null
                          : Text(
                              trailing(row)!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: orange,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
