part of 'main.dart';

class MixhouseApp extends StatefulWidget {
  const MixhouseApp({super.key});
  @override
  State<MixhouseApp> createState() => _MixhouseAppState();
}

class _MixhouseAppState extends State<MixhouseApp> {
  final session = Session();
  final appLinks = AppLinks();
  StreamSubscription<Uri>? linkSubscription;
  @override
  void initState() {
    super.initState();
    session.restore();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) session.completeGoogleLogin(uri);
    });
    linkSubscription = appLinks.uriLinkStream.listen(
      session.completeGoogleLogin,
    );
  }

  @override
  void dispose() {
    linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mixhouse',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          surface: const Color(0xfff7f3ed),
        ),
        scaffoldBackgroundColor: const Color(0xfff7f3ed),
        fontFamily: 'Arial',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffe7e5e4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffe7e5e4)),
          ),
        ),
      ),
      home: session.loading
          ? const Splash()
          : session.user == null
          ? Login(session)
          : Home(session),
    ),
  );
}
