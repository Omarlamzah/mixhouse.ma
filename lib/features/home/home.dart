part of '../../main.dart';

class Home extends StatefulWidget {
  final Session session;
  const Home(this.session, {super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int selected = 0;
  bool expanded = true;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      drawer: wide ? null : Drawer(child: side(true)),
      appBar: wide
          ? null
          : AppBar(title: brand(), backgroundColor: Colors.white),
      body: Row(
        children: [
          if (wide) side(expanded),
          Expanded(
            child: nav[selected].$1 == 'POS'
                ? PosPage(widget.session.api)
                : nav[selected].$1 == 'Dashboard'
                ? Dashboard(widget.session.api, widget.session.user!)
                : nav[selected].$1 == 'Settings'
                ? SettingsPage(api: widget.session.api)
                : AdminModulePage(
                    api: widget.session.api,
                    title: nav[selected].$1,
                    icon: nav[selected].$2,
                  ),
          ),
        ],
      ),
    );
  }

  Widget side(bool open) => Container(
    width: open ? 248 : 76,
    color: Colors.white,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: open
                ? Row(
                    children: [
                      Expanded(child: brand()),
                      if (MediaQuery.sizeOf(context).width >= 800)
                        IconButton(
                          onPressed: () => setState(() => expanded = false),
                          icon: const Icon(Icons.chevron_left),
                        ),
                    ],
                  )
                : IconButton(
                    onPressed: () => setState(() => expanded = true),
                    icon: const Icon(Icons.chevron_right),
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: nav.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  selected: i == selected,
                  selectedTileColor: const Color(0xfffff7ed),
                  selectedColor: orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(nav[i].$2),
                  title: open
                      ? Text(
                          nav[i].$1,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      : null,
                  onTap: () {
                    setState(() => selected = i);
                    if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xffffedd5),
              child: Text(
                widget.session.user!.name.isEmpty
                    ? 'M'
                    : widget.session.user!.name[0].toUpperCase(),
                style: const TextStyle(
                  color: orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: open
                ? Text(
                    widget.session.user!.name,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            subtitle: open ? Text(widget.session.user!.role) : null,
            trailing: open
                ? IconButton(
                    onPressed: widget.session.logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                  )
                : null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class Dashboard extends StatefulWidget {
  final Api api;
  final User user;
  const Dashboard(this.api, this.user, {super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map? report;
  List orders = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final d = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final values = await Future.wait([
        widget.api.request('/admin/reports/range?start_date=$d&end_date=$d'),
        widget.api.request('/admin/orders?date=$d'),
      ]);
      if (mounted) {
        setState(() {
          report = values[0];
          orders = (values[1]['data'] ?? []) as List;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final r = report?['data'] ?? report ?? {};
    num val(List<String> keys) {
      dynamic v = r;
      for (final k in keys) {
        if (v is Map) v = v[k];
      }
      return num.tryParse('$v') ?? 0;
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${DateTime.now().hour < 12 ? 'morning' : 'afternoon'}, ${widget.user.name.split(' ').first}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Here’s what’s happening at Mixhouse today.",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (loading)
            const LinearProgressIndicator()
          else
            LayoutBuilder(
              builder: (_, x) => Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  metric(
                    'Revenue',
                    '${val(['summary', 'revenue']).toStringAsFixed(2)} DH',
                    Icons.payments_outlined,
                    Colors.green,
                    x.maxWidth,
                  ),
                  metric(
                    'Orders',
                    '${orders.length}',
                    Icons.receipt_long_outlined,
                    orange,
                    x.maxWidth,
                  ),
                  metric(
                    'Cash',
                    '${val(['summary', 'cash_revenue']).toStringAsFixed(2)} DH',
                    Icons.account_balance_wallet_outlined,
                    Colors.blue,
                    x.maxWidth,
                  ),
                  metric(
                    'Card',
                    '${val(['summary', 'card_revenue']).toStringAsFixed(2)} DH',
                    Icons.credit_card,
                    Colors.purple,
                    x.maxWidth,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          const Text(
            'Recent orders',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            child: orders.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(42),
                    child: Center(
                      child: Text(
                        'No orders yet today',
                        style: TextStyle(color: Colors.black45),
                      ),
                    ),
                  )
                : Column(
                    children: orders
                        .take(8)
                        .map(
                          (o) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xfffff7ed),
                              child: Text(
                                '#${o['daily_ticket_number'] ?? o['id']}',
                                style: const TextStyle(
                                  color: orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              o['guest_name'] ?? 'Walk-in customer',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${o['order_type'] ?? 'eat_in'} • ${o['payment_method'] ?? 'cash'}',
                            ),
                            trailing: Text(
                              '${o['total']} DH',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget metric(
    String label,
    String value,
    IconData icon,
    Color color,
    double w,
  ) => SizedBox(
    width: w > 1100
        ? (w - 42) / 4
        : w > 550
        ? (w - 14) / 2
        : w,
    child: Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
