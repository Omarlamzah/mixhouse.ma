part of '../../main.dart';

class PosPage extends StatefulWidget {
  final Api api;
  const PosPage(this.api, {super.key});
  @override
  State<PosPage> createState() => _PosPageState();
}

enum _CheckoutAction { charge, sendToDesktop, printOnDesktop }

class _PosPageState extends State<PosPage> {
  List products = [], categories = [], cart = [];
  Map<String, dynamic>? cashSession;
  Map<String, dynamic>? linkedCustomer;
  int pointsRedeemed = 0;
  int loyaltyRateDh = 150, loyaltyRatePts = 50, loyaltyMinOrder = 150;
  int? category;
  String search = '';
  bool loading = true;
  bool requestingDrawer = false;
  Timer? sessionRefreshTimer;
  @override
  void initState() {
    super.initState();
    load();
    sessionRefreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => syncCashSession(),
    );
  }

  @override
  void dispose() {
    sessionRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await Future.wait([
        widget.api.request('/products'),
        widget.api.request('/categories'),
      ]);
      setState(() {
        products = d[0]['data'] ?? [];
        categories = d[1]['data'] ?? [];
        loading = false;
      });
      await syncCashSession();
      loadLoyaltySettings();
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> syncCashSession() async {
    try {
      final response = await widget.api.request('/cash-sessions/today');
      if (!mounted) return;
      final dynamic unwrapped = response is Map && response['data'] is Map
          ? response['data']
          : response;
      setState(() {
        cashSession = unwrapped is Map && unwrapped['exists'] != false
            ? Map<String, dynamic>.from(unwrapped)
            : null;
      });
    } catch (error) {
      if (kDebugMode) debugPrint('Cash session refresh failed: $error');
    }
  }

  Future<void> loadLoyaltySettings() async {
    try {
      final response = await widget.api.request('/admin/settings');
      final settings = response is Map && response['data'] is Map
          ? response['data'] as Map
          : response as Map;
      if (!mounted) return;
      setState(() {
        loyaltyRateDh =
            int.tryParse('${settings['loyalty_rate_dh'] ?? 150}') ?? 150;
        loyaltyRatePts =
            int.tryParse('${settings['loyalty_rate_pts'] ?? 50}') ?? 50;
        loyaltyMinOrder =
            int.tryParse('${settings['loyalty_min_order'] ?? 150}') ?? 150;
      });
    } catch (_) {}
  }

  bool get registerOpen =>
      cashSession != null &&
      cashSession!['id'] != null &&
      (cashSession!['closed_at'] == null || cashSession!['closed_at'] == '');

  Future<String?> askAmount(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: 'DH'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> toggleRegister() async {
    final amount = await askAmount(
      registerOpen ? 'Close register' : 'Open register',
      registerOpen ? 'Counted closing cash' : 'Opening cash',
    );
    if (amount == null || double.tryParse(amount) == null) return;
    try {
      await widget.api.request(
        registerOpen ? '/cash-sessions/close' : '/cash-sessions/open',
        method: 'POST',
        body: registerOpen
            ? {'closing_cash': double.parse(amount)}
            : {'opening_cash': double.parse(amount)},
      );
      await syncCashSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> openDesktopDrawer() async {
    setState(() => requestingDrawer = true);
    try {
      await widget.api.request('/desktop/cash-drawer/open', method: 'POST');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash drawer command sent to desktop.')),
        );
      }
    } catch (error) {
      showPosError(error);
    } finally {
      if (mounted) setState(() => requestingDrawer = false);
    }
  }

  Future<void> addCharge() async {
    if (!registerOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open the register before recording a charge.'),
        ),
      );
      return;
    }
    final description = TextEditingController(),
        amount = TextEditingController();
    String category = 'other', payment = 'cash';
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('New charge'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.notes),
                  ),
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
                    prefixIcon: Icon(Icons.payments_outlined),
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
              child: const Text('Save charge'),
            ),
          ],
        ),
      ),
    );
    if (submit == true &&
        description.text.trim().isNotEmpty &&
        (double.tryParse(amount.text) ?? 0) > 0) {
      try {
        await widget.api.request(
          '/expenses',
          method: 'POST',
          body: {
            'description': description.text.trim(),
            'amount': double.parse(amount.text),
            'category': category,
            'payment_method': payment,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Charge recorded.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
    description.dispose();
    amount.dispose();
  }

  void add(Map p) {
    final i = cart.indexWhere((x) => x['product']['id'] == p['id']);
    setState(() {
      if (i < 0) {
        cart.add({'product': p, 'qty': 1});
      } else {
        cart[i]['qty']++;
      }
    });
  }

  double get total => cart.fold<double>(
    0,
    (s, x) => s + (double.tryParse('${x['product']['price']}') ?? 0) * x['qty'],
  );
  double get loyaltyDiscount => loyaltyRatePts <= 0
      ? 0
      : (pointsRedeemed * loyaltyRateDh / loyaltyRatePts).floorToDouble().clamp(
          0,
          total,
        );
  double get payableTotal =>
      (total - loyaltyDiscount).clamp(0, double.infinity);
  int get pointsToEarn =>
      linkedCustomer != null && total >= loyaltyMinOrder && loyaltyRateDh > 0
      ? (total / loyaltyRateDh * loyaltyRatePts).floor()
      : 0;

  Future<void> pickCustomer([StateSetter? refreshSheet]) async {
    List<Map<String, dynamic>> customers = [];
    try {
      final response = await widget.api.request('/pos/customers');
      customers = ((response['data'] ?? response) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      showPosError(e);
      return;
    }
    if (!mounted) return;
    var query = '';
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final filtered = customers
              .where(
                (c) => '${c['name']} ${c['phone'] ?? ''} ${c['email'] ?? ''}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: const Text('Loyalty customer'),
            content: SizedBox(
              width: 480,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setDialog(() => query = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name or phone…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final created = await createCustomer();
                        if (created != null && context.mounted) {
                          Navigator.pop(context, created);
                        }
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('New customer'),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No customers found'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text('${c['name']}'[0].toUpperCase()),
                                ),
                                title: Text(
                                  '${c['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${c['phone'] ?? c['email'] ?? 'No contact'}',
                                ),
                                trailing: Chip(
                                  avatar: const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  label: Text('${c['points'] ?? 0} pts'),
                                ),
                                onTap: () => Navigator.pop(context, c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        linkedCustomer = selected;
        pointsRedeemed = 0;
      });
      refreshSheet?.call(() {});
    }
  }

  Future<Map<String, dynamic>?> createCustomer() async {
    final name = TextEditingController(), phone = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New loyalty customer'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
    Map<String, dynamic>? result;
    if (save == true && name.text.trim().isNotEmpty) {
      try {
        final response = await widget.api.request(
          '/pos/customers',
          method: 'POST',
          body: {'name': name.text.trim(), 'phone': phone.text.trim()},
        );
        result = Map<String, dynamic>.from(response['data'] ?? response);
      } catch (e) {
        showPosError(e);
      }
    }
    name.dispose();
    phone.dispose();
    return result;
  }

  void showPosError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  int get cartItemCount =>
      cart.fold<int>(0, (count, item) => count + (item['qty'] as int));

  Future<void> openMobileCart() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, refreshSheet) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: cartPanel(refreshSheet: refreshSheet, mobileSheet: true),
      ),
    ),
  );

  Future<void> checkout({
    _CheckoutAction action = _CheckoutAction.charge,
  }) async {
    final sendsToDesktop = action != _CheckoutAction.charge;
    final printsOnDesktop = action == _CheckoutAction.printOnDesktop;
    final details = await showDialog<_CheckoutDetails>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(total: payableTotal),
    );
    if (details == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final response = await widget.api.request(
        '/orders',
        method: 'POST',
        body: {
          'items': cart
              .map(
                (item) => {
                  'product_id': item['product']['id'],
                  'quantity': item['qty'],
                  'selected_options': <int>[],
                },
              )
              .toList(),
          'payment_method': details.paymentMethod,
          'order_type': details.orderType,
          // Mobile orders enter the desktop POS notification/validation queue.
          'source': sendsToDesktop ? 'qr' : 'pos',
          'order_status': 'pending',
          if (details.tableNumber.isNotEmpty)
            'table_number': details.tableNumber,
          if (details.phone.isNotEmpty) 'guest_phone': details.phone,
          if (details.address.isNotEmpty) 'delivery_address': details.address,
          'delivery_fee': 0,
          'discount': loyaltyDiscount,
          if (linkedCustomer != null) 'customer_id': linkedCustomer!['id'],
          if (pointsRedeemed > 0) 'points_redeemed': pointsRedeemed,
        },
      );
      if (!mounted) return;
      final order = response['data'] ?? response;
      if (printsOnDesktop) {
        await widget.api.request(
          '/orders/${order['id']}/validate-print',
          method: 'POST',
        );
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        cart.clear();
        linkedCustomer = null;
        pointsRedeemed = 0;
      });
      await showDialog<void>(
        context: context,
        builder: (_) => _OrderSuccessDialog(
          api: widget.api,
          order: order,
          sentToDesktop: sendsToDesktop,
          initiallySent: printsOnDesktop,
          loyaltyMinOrder: loyaltyMinOrder,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    final mobile = MediaQuery.sizeOf(c).width <= 720;
    final systemBottom = MediaQuery.viewPaddingOf(c).bottom;
    final filtered = products
        .where(
          (p) =>
              (category == null || p['category_id'] == category) &&
              '${p['name']}'.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: registerOpen ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                registerOpen
                                    ? 'Register open'
                                    : 'Register closed',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Record charge',
                              onPressed: addCharge,
                              icon: const Icon(Icons.receipt_long_outlined),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Open desktop cash drawer',
                              onPressed: requestingDrawer
                                  ? null
                                  : openDesktopDrawer,
                              icon: requestingDrawer
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.point_of_sale_outlined),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: toggleRegister,
                              style: FilledButton.styleFrom(
                                backgroundColor: registerOpen
                                    ? Colors.red.shade600
                                    : Colors.green.shade600,
                              ),
                              icon: Icon(
                                registerOpen
                                    ? Icons.lock_outline
                                    : Icons.lock_open,
                              ),
                              label: Text(registerOpen ? 'Close' : 'Open'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (v) => setState(() => search = v),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search products…',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 58,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: category == null,
                          onSelected: (_) => setState(() => category = null),
                        ),
                        ...categories.map(
                          (x) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(x['name']),
                              selected: category == x['id'],
                              onSelected: (_) =>
                                  setState(() => category = x['id']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : GridView.builder(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              mobile ? 112 + systemBottom : 16,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  mainAxisExtent: 190,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final p = filtered[i];
                              final imageUrl = storageUrl(p['image_url']);
                              return InkWell(
                                onTap: () => add(p),
                                borderRadius: BorderRadius.circular(18),
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  color: Colors.white,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: imageUrl == null
                                            ? const _ProductImageFallback()
                                            : Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                filterQuality:
                                                    FilterQuality.medium,
                                                loadingBuilder:
                                                    (context, child, progress) {
                                                      if (progress == null) {
                                                        return child;
                                                      }
                                                      return const ColoredBox(
                                                        color: Color(
                                                          0xfff5f5f4,
                                                        ),
                                                        child: Center(
                                                          child: SizedBox.square(
                                                            dimension: 22,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: orange,
                                                                ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      if (kDebugMode) {
                                                        debugPrint(
                                                          '🖼️ Failed to load $imageUrl: $error',
                                                        );
                                                      }
                                                      return const _ProductImageFallback();
                                                    },
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          10,
                                          12,
                                          12,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${p['name']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${p['price']} DH',
                                              style: const TextStyle(
                                                color: orange,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            if (!mobile) SizedBox(width: 360, child: cartPanel()),
          ],
        ),
        if (mobile && cart.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: systemBottom + 16,
            child: Material(
              color: ink,
              elevation: 12,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: openMobileCart,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Badge(
                        backgroundColor: orange,
                        label: Text('$cartItemCount'),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'View current order',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${payableTotal.toStringAsFixed(2)} DH',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget cartPanel({
    StateSetter? refreshSheet,
    bool mobileSheet = false,
  }) => Container(
    color: Colors.white,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: orange),
                const SizedBox(width: 10),
                const Text(
                  'Current order',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                if (mobileSheet)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: linkedCustomer == null
                ? OutlinedButton.icon(
                    onPressed: () => pickCustomer(refreshSheet),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Link loyalty customer'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfffffbeb),
                      border: Border.all(color: const Color(0xfffde68a)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xfffef3c7),
                              child: Icon(Icons.star, color: Colors.amber),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${linkedCustomer!['name']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${linkedCustomer!['points'] ?? 0} loyalty points',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  linkedCustomer = null;
                                  pointsRedeemed = 0;
                                });
                                refreshSheet?.call(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        if ((linkedCustomer!['points'] as num? ?? 0) > 0)
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Use loyalty points',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              pointsRedeemed > 0
                                  ? '-${loyaltyDiscount.toStringAsFixed(2)} DH'
                                  : 'Available discount',
                            ),
                            value: pointsRedeemed > 0,
                            onChanged: (use) {
                              setState(
                                () => pointsRedeemed = use
                                    ? (linkedCustomer!['points'] as num).toInt()
                                    : 0,
                              );
                              refreshSheet?.call(() {});
                            },
                          ),
                        if (pointsToEarn > 0 && pointsRedeemed == 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'This order earns $pointsToEarn points',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xffa16207),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Text(
                      'Tap a product to add it',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.length,
                    itemBuilder: (_, i) {
                      final x = cart[i];
                      return ListTile(
                        title: Text(
                          x['product']['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${x['product']['price']} DH'),
                        trailing: SizedBox(
                          width: 132,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    if (x['qty'] > 1) {
                                      x['qty']--;
                                    } else {
                                      cart.removeAt(i);
                                    }
                                  });
                                  refreshSheet?.call(() {});
                                },
                                icon: const Icon(Icons.remove, size: 18),
                              ),
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '${x['qty']}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() => x['qty']++);
                                  refreshSheet?.call(() {});
                                },
                                icon: const Icon(Icons.add, size: 18),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (loyaltyDiscount > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(color: Colors.black54),
                      ),
                      Text('${total.toStringAsFixed(2)} DH'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Loyalty discount',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '-${loyaltyDiscount.toStringAsFixed(2)} DH',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${payableTotal.toStringAsFixed(2)} DH',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: cart.isEmpty
                      ? null
                      : () {
                          if (mobileSheet) Navigator.pop(context);
                          checkout();
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Charge order'),
                  style: FilledButton.styleFrom(
                    backgroundColor: orange,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: cart.isEmpty
                      ? null
                      : () {
                          if (mobileSheet) Navigator.pop(context);
                          checkout(action: _CheckoutAction.sendToDesktop);
                        },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send order to Desktop'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff2563eb),
                    side: const BorderSide(color: Color(0xff93c5fd)),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: cart.isEmpty
                      ? null
                      : () {
                          if (mobileSheet) Navigator.pop(context);
                          checkout(action: _CheckoutAction.printOnDesktop);
                        },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Validate & Print on Desktop'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: orange,
                    side: const BorderSide(color: orange),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xfff5f5f4),
    child: Center(
      child: Icon(Icons.restaurant, size: 42, color: Color(0xffd6d3d1)),
    ),
  );
}

class _CheckoutDetails {
  final String paymentMethod, orderType, tableNumber, phone, address;
  const _CheckoutDetails({
    required this.paymentMethod,
    required this.orderType,
    required this.tableNumber,
    required this.phone,
    required this.address,
  });
}

class _CheckoutDialog extends StatefulWidget {
  final double total;
  const _CheckoutDialog({required this.total});
  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  String payment = 'cash', type = 'eat_in';
  final table = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  @override
  void dispose() {
    table.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  void confirm() {
    if (type == 'delivery' &&
        (phone.text.trim().isEmpty || address.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone and address are required.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _CheckoutDetails(
        paymentMethod: payment,
        orderType: type,
        tableNumber: type == 'eat_in' ? table.text.trim() : '',
        phone: type == 'delivery' || type == 'pickup' || type == 'glovo'
            ? phone.text.trim()
            : '',
        address: type == 'delivery' ? address.text.trim() : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(
      'Complete order',
      style: TextStyle(fontWeight: FontWeight.w900),
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xfffff7ed),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount to charge',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${widget.total.toStringAsFixed(2)} DH',
                    style: const TextStyle(
                      fontSize: 24,
                      color: orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Order type',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  const [
                        ('eat_in', 'Eat in'),
                        ('pickup', 'Pickup'),
                        ('delivery', 'Delivery'),
                        ('glovo', 'Glovo'),
                      ]
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.$2),
                          selected: type == item.$1,
                          onSelected: (_) => setState(() => type = item.$1),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 22),
            const Text(
              'Payment method',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'cash',
                  label: Text('Cash'),
                  icon: Icon(Icons.payments_outlined),
                ),
                ButtonSegment(
                  value: 'card',
                  label: Text('Card'),
                  icon: Icon(Icons.credit_card),
                ),
              ],
              selected: {payment},
              onSelectionChanged: (value) =>
                  setState(() => payment = value.first),
            ),
            if (type == 'eat_in') ...[
              const SizedBox(height: 18),
              TextField(
                controller: table,
                decoration: const InputDecoration(
                  labelText: 'Table number',
                  prefixIcon: Icon(Icons.table_restaurant),
                ),
              ),
            ],
            if (type == 'delivery' || type == 'pickup' || type == 'glovo') ...[
              const SizedBox(height: 18),
              TextField(
                controller: phone,
                decoration: InputDecoration(
                  labelText: type == 'delivery' ? 'Phone *' : 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
            ],
            if (type == 'delivery') ...[
              const SizedBox(height: 12),
              TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Delivery address *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: confirm,
        style: FilledButton.styleFrom(backgroundColor: orange),
        icon: const Icon(Icons.check),
        label: const Text('Confirm & charge'),
      ),
    ],
  );
}

class _OrderSuccessDialog extends StatefulWidget {
  final Api api;
  final dynamic order;
  final bool sentToDesktop;
  final bool initiallySent;
  final int loyaltyMinOrder;
  const _OrderSuccessDialog({
    required this.api,
    required this.order,
    required this.sentToDesktop,
    required this.loyaltyMinOrder,
    this.initiallySent = false,
  });
  @override
  State<_OrderSuccessDialog> createState() => _OrderSuccessDialogState();
}

class _OrderSuccessDialogState extends State<_OrderSuccessDialog> {
  bool sending = false;
  late bool sent;
  String? error;

  @override
  void initState() {
    super.initState();
    sent = widget.initiallySent;
  }

  Future<void> validateAndPrint() async {
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.api.request(
        '/orders/${widget.order['id']}/validate-print',
        method: 'POST',
      );
      if (mounted) {
        setState(() {
          sending = false;
          sent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final number =
        widget.order['daily_ticket_number'] ?? widget.order['id'] ?? '—';
    return AlertDialog(
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xffdcfce7),
              child: Icon(
                Icons.check_rounded,
                size: 46,
                color: Color(0xff16a34a),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Order confirmed!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Order #$number',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${widget.order['total'] ?? '0.00'} DH',
              style: const TextStyle(
                fontSize: 30,
                color: orange,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (widget.order['customer'] is Map) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffffbeb),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xfffde68a)),
                ),
                child: Column(
                  children: [
                    Text(
                      '⭐ ${widget.order['customer']['name']} linked',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (widget.order['points_earned'] as num? ?? 0) > 0
                          ? '+${widget.order['points_earned']} loyalty points earned'
                          : 'No points earned — minimum order is ${widget.loyaltyMinOrder} DH',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.sentToDesktop) ...[
              const SizedBox(height: 14),
              Text(
                sent
                    ? 'Print command sent. The desktop will print this order automatically.'
                    : 'Order saved. Send it to the desktop printer when ready.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: sent ? Colors.green.shade700 : Colors.black54,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (widget.sentToDesktop)
          FilledButton.icon(
            onPressed: sending ? null : validateAndPrint,
            style: FilledButton.styleFrom(
              backgroundColor: orange,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print_outlined),
            label: Text(
              sent ? 'Print again on Desktop' : 'Validate & Print on Desktop',
            ),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('New order'),
        ),
      ],
    );
  }
}
