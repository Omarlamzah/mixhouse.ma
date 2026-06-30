part of '../../main.dart';

class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext c) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: orange)),
  );
}

class Login extends StatefulWidget {
  final Session session;
  const Login(this.session, {super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false, hide = true;
  String? error;
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.login(email.text.trim(), password.text);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        if (MediaQuery.sizeOf(context).width > 850)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff7c2d12), orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brand(light: true),
                    const Spacer(),
                    const Text(
                      'Run your restaurant\nbeautifully.',
                      style: TextStyle(
                        fontSize: 48,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sales, orders and your entire team — one calm workspace.',
                      style: TextStyle(fontSize: 17, color: Color(0xffffedd5)),
                    ),
                    const Spacer(),
                    const Text(
                      'MIXHOUSE  •  RESTAURANT OS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (MediaQuery.sizeOf(context).width <= 850) brand(),
                    const SizedBox(height: 42),
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to your Mixhouse workspace.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    if (error != null || widget.session.authError != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          error ?? widget.session.authError!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline),
                        hintText: 'you@example.com',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: password,
                      obscureText: hide,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => hide = !hide),
                          icon: Icon(
                            hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          '$apiUrl/auth/google/redirect?type=staff&mobile=1',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xff4285f4),
                        ),
                      ),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget brand({bool light = false}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: light ? Colors.white : orange,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'M',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: light ? orange : Colors.white,
        ),
      ),
    ),
    const SizedBox(width: 12),
    Text(
      'Mixhouse',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: light ? Colors.white : ink,
      ),
    ),
  ],
);

const nav = [
  ('Dashboard', Icons.grid_view_rounded),
  ('Orders', Icons.receipt_long_outlined),
  ('Charges', Icons.payments_outlined),
  ('POS', Icons.point_of_sale_rounded),
  ('Products', Icons.shopping_bag_outlined),
  ('Categories', Icons.category_outlined),
  ('Customers', Icons.people_outline),
  ('Staff', Icons.badge_outlined),
  ('Suppliers', Icons.local_shipping_outlined),
  ('Stock', Icons.inventory_2_outlined),
  ('Reports', Icons.bar_chart_rounded),
  ('Settings', Icons.settings_outlined),
];
