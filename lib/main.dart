import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

part 'screens/dashboard.dart';
part 'screens/workflows.dart';
part 'screens/staff.dart';

const ink = Color(0xff142f26);
const green = Color(0xff176648);
const canvas = Color(0xfff5f7f2);
const pale = Color(0xffe6f0e6);
const lime = Color(0xffd8eea0);
const muted = Color(0xff50675c);

const roles = {
  'citoyen': 'Citoyen',
  'agent': 'Agent de collecte',
  'centre': 'Centre de recyclage',
  'admin': 'Administrateur',
};
const categoryIcons = {
  'Plastique': Icons.local_drink_outlined,
  'Papier / carton': Icons.inventory_2_outlined,
  'Verre': Icons.wine_bar_outlined,
  'Métal': Icons.lunch_dining_outlined,
  'Organique': Icons.compost_outlined,
};
const mapEnabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');

void main() => runApp(const EcoVision());

class Api {
  static const configuredUrl = String.fromEnvironment('API_URL');
  static final base = configuredUrl.isNotEmpty
      ? configuredUrl
      : 'http://${!kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1'}:8000';
  String? token;
  Map<String, String> get headers => {
    if (token != null) 'Authorization': 'Bearer $token',
  };

  dynamic decode(http.Response response) {
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final detail = value['detail'];
      throw StateError(
        detail is String ? detail : 'Vérifiez les champs saisis.',
      );
    }
    return value;
  }

  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final request = http.Request(method, Uri.parse('$base$path'));
    request.headers.addAll(headers);
    if (data != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(data);
    }
    return decode(
      await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 12)),
      ),
    );
  }

  Future<dynamic> scan(XFile file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$base/scan'));
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await file.readAsBytes(),
        filename: file.name,
      ),
    );
    return decode(
      await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      ),
    );
  }
}

final api = Api();
String errorText(Object e) => e is StateError
    ? e.message
    : 'Connexion ou opération indisponible. Réessayez.';
List<Map<String, dynamic>> rows(dynamic value) =>
    List<Map<String, dynamic>>.from(value as List);

Future<Position> locate() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Activez la localisation sur votre appareil.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw StateError(
      'Autorisez la localisation dans les paramètres de votre appareil.',
    );
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(timeLimit: Duration(seconds: 12)),
  );
}

class EcoVision extends StatelessWidget {
  const EcoVision({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EcoVision',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: Colors.white,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: canvas,
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Map<String, dynamic>? user;
  Map<String, dynamic> categories = {};
  bool demo = false;
  bool loading = true;
  String? connectionError;
  int index = 0;
  String get role => user?['role'] ?? 'citoyen';

  @override
  void initState() {
    super.initState();
    connect();
  }

  Future<void> connect() async {
    setState(() {
      loading = true;
      connectionError = null;
    });
    try {
      final config = await api.call('/config');
      if (!mounted) return;
      setState(() {
        demo = config['demo'];
        categories = Map<String, dynamic>.from(config['categories']);
      });
      if (demo && user == null) await signIn('/demo/citoyen');
    } catch (e) {
      if (mounted) setState(() => connectionError = errorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> signIn(String path, [Map<String, dynamic>? data]) async {
    final result = await api.call(path, method: 'POST', data: data);
    if (!mounted) return;
    setState(() {
      api.token = result['token'];
      user = Map<String, dynamic>.from(result['user']);
      index = 0;
    });
  }

  Future<void> refreshUser() async {
    final result = await api.call('/me');
    if (mounted) setState(() => user = Map<String, dynamic>.from(result));
  }

  void choose(int value) {
    setState(() => index = value);
    if (value == 0 && user != null) refreshUser().catchError((Object _) {});
  }

  Future<void> account() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(user?['name'] ?? 'Compte'),
                subtitle: Text(user?['email'] ?? ''),
              ),
              if (demo)
                ...roles.entries.map(
                  (entry) => ListTile(
                    leading: const Icon(Icons.switch_account_outlined),
                    title: Text(entry.value),
                    subtitle: const Text('Compte de démonstration'),
                    onTap: () => Navigator.pop(context, entry.key),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Se déconnecter'),
                onTap: () => Navigator.pop(context, 'logout'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (selection == 'logout') {
      setState(() {
        api.token = null;
        user = null;
        index = 0;
      });
      return;
    }
    try {
      await signIn('/demo/$selection');
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (connectionError != null) {
      return Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: connect,
            icon: const Icon(Icons.refresh),
            label: Text(connectionError!),
          ),
        ),
      );
    }
    if (user == null) return AuthPage(demo: demo, signIn: signIn);
    final isCitizen = role == 'citoyen';
    final tabs = isCitizen
        ? const [
            (Icons.space_dashboard_outlined, 'Accueil'),
            (Icons.document_scanner_outlined, 'Scanner'),
            (Icons.map_outlined, 'Carte'),
            (Icons.flag_outlined, 'Signalements'),
            (Icons.stars_outlined, 'EcoPoints'),
          ]
        : switch (role) {
            'centre' => const [
              (Icons.place_outlined, 'Centres'),
              (Icons.recycling, 'Dépôts'),
            ],
            'agent' => const [(Icons.flag_outlined, 'Interventions')],
            _ => const [
              (Icons.dashboard_outlined, 'Tableau de bord'),
              (Icons.flag_outlined, 'Signalements'),
              (Icons.place_outlined, 'Centres'),
              (Icons.recycling, 'Dépôts'),
              (Icons.stars_outlined, 'Récompenses'),
            ],
          };
    final Widget page;
    if (isCitizen) {
      page = switch (index) {
        1 => Scanner(categories: categories, onMap: () => choose(2)),
        2 => MapPage(demo: demo),
        3 => const Reports(),
        4 => Rewards(
          demo: demo,
          onChanged: refreshUser,
          points: user!['points'],
        ),
        _ => Dashboard(
          name: user!['name'],
          points: user!['points'],
          onNavigate: choose,
        ),
      };
    } else {
      page = switch (tabs[index].$2) {
        'Centres' => CentreAdmin(user: user!),
        'Dépôts' => const Deposits(staff: true),
        'Interventions' || 'Signalements' => const Reports(staff: true),
        'Récompenses' => Rewards(
          demo: demo,
          staff: true,
          onChanged: refreshUser,
          points: 0,
        ),
        _ => Admin(demo: demo, userId: user!['id']),
      };
    }
    return LayoutBuilder(
      builder: (context, limits) {
        final wide = limits.maxWidth >= 930;
        final links = List<Widget>.generate(
          tabs.length,
          (i) => NavItem(
            icon: tabs[i].$1,
            label: tabs[i].$2,
            selected: i == index,
            onTap: () => choose(i),
            wide: wide,
          ),
        );
        return Scaffold(
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Container(
                    width: 230,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(19, 26, 19, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 6, bottom: 34),
                          child: Brand(),
                        ),
                        ...links,
                        const Spacer(),
                        if (demo)
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              'Données de démonstration',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 7,
                          ),
                          leading: const Icon(Icons.account_circle_outlined),
                          title: Text(
                            user!['name'],
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(roles[role]!),
                          onTap: account,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 30 : 17,
                          vertical: 8,
                        ),
                        color: Colors.white,
                        child: Row(
                          children: [
                            if (!wide)
                              const Brand()
                            else
                              Text(
                                tabs[index].$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const Spacer(),
                            if (demo)
                              const Tag('Démo', icon: Icons.science_outlined),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              onPressed: account,
                              tooltip: 'Compte et rôle',
                              icon: const Icon(Icons.person_outline),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: KeyedSubtree(
                          key: ValueKey('${user!['id']}-$index'),
                          child: page,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide || links.length < 2
              ? null
              : SafeArea(
                  top: false,
                  child: Material(
                    color: Colors.white,
                    child: Row(
                      children: links
                          .map((link) => Expanded(child: link))
                          .toList(),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

void notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.demo, required this.signIn});
  final bool demo;
  final Future<void> Function(String, [Map<String, dynamic>?]) signIn;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;

  Future<void> submit([String? demoRole]) async {
    if (demoRole == null && !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (demoRole != null) {
        await widget.signIn('/demo/$demoRole');
      } else {
        await widget.signIn(register ? '/register' : '/login', {
          'email': email.text.trim(),
          'password': password.text,
          if (register) 'name': name.text.trim(),
        });
      }
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      maxWidth: 500,
      children: [
        const Brand(),
        const SizedBox(height: 38),
        Heading(
          register ? 'Créer un compte' : 'Connexion',
          'Accédez à votre espace EcoVision.',
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (register) ...[
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) =>
                        v!.trim().length < 2 ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                  ),
                  validator: (v) =>
                      !v!.contains('@') ? 'Adresse invalide' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  validator: (v) =>
                      v!.length < 8 ? 'Au moins 8 caractères' : null,
                  onFieldSubmitted: (_) {
                    if (!busy) submit();
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : () => submit(),
                  child: Text(register ? 'Créer mon compte' : 'Se connecter'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => register = !register),
                  child: Text(
                    register ? 'J’ai déjà un compte' : 'Créer un compte',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.demo) ...[
          const SizedBox(height: 20),
          const Text(
            'Comptes de démonstration',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: roles.entries
                .map(
                  (entry) => OutlinedButton(
                    onPressed: busy ? null : () => submit(entry.key),
                    child: Text(entry.value),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    ),
  );
}
