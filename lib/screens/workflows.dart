part of '../main.dart';

class DataPanel extends StatelessWidget {
  const DataPanel(this.future, this.builder, this.retry, {super.key});
  final Future<dynamic> future;
  final Widget Function(dynamic) builder;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(22),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return Panel(
          child: Column(
            children: [
              Text(errorText(snapshot.error!)),
              TextButton(onPressed: retry, child: const Text('Réessayer')),
            ],
          ),
        );
      }
      return builder(snapshot.data);
    },
  );
}

mixin LoadData<T extends StatefulWidget> on State<T> {
  late Future<dynamic> data;
  Future<dynamic> load();
  @override
  void initState() {
    super.initState();
    data = load();
  }

  void reload() => setState(() => data = load());
}

class Scanner extends StatefulWidget {
  const Scanner({super.key, required this.categories, required this.onMap});
  final Map<String, dynamic> categories;
  final VoidCallback onMap;
  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  Uint8List? preview;
  String? category;
  double? confidence;
  bool manual = false;
  bool busy = false;

  Future<void> pick(ImageSource source) async {
    setState(() => busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 84,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        preview = bytes;
        category = null;
        confidence = null;
        manual = false;
      });
      final result = await api.scan(file);
      if (!mounted) return;
      setState(() {
        category = result['category'];
        confidence = (result['confidence'] as num?)?.toDouble();
        manual = result['manual'] == true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => manual = true);
        notify(context, errorText(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    maxWidth: 760,
    children: [
      const Heading(
        'Scanner un déchet',
        'Photographiez un seul déchet, bien éclairé et centré.',
      ),
      Panel(
        child: Column(
          children: [
            if (preview != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(preview!, height: 230, fit: BoxFit.contain),
              )
            else
              const Padding(
                padding: EdgeInsets.all(21),
                child: Icon(
                  Icons.document_scanner_outlined,
                  color: green,
                  size: 76,
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 9,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (!kIsWeb)
                  FilledButton.icon(
                    onPressed: busy ? null : () => pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Prendre une photo'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => pick(ImageSource.gallery),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Choisir une image'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          manual = true;
                          confidence = null;
                        }),
                  child: const Text('Choisir la matière'),
                ),
              ],
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      if (manual) ...[
        if (preview != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 9),
            child: Text(
              'Identification automatique indisponible ou incertaine. Choisissez une matière.',
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: widget.categories.keys
              .map(
                (value) => ChoiceChip(
                  avatar: Icon(categoryIcons[value], size: 17),
                  label: Text(value),
                  selected: category == value,
                  onSelected: (_) => setState(() => category = value),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
      ],
      if (category != null)
        Panel(
          color: pale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category!,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                ),
              ),
              if (confidence != null)
                Text('Confiance du modèle : ${(confidence! * 100).round()} %'),
              const SizedBox(height: 7),
              Text(widget.categories[category] ?? ''),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: widget.onMap,
                icon: const Icon(Icons.place_outlined),
                label: const Text('Voir les points de collecte'),
              ),
            ],
          ),
        ),
    ],
  );
}

Future<void> openMaps(BuildContext context, double lat, double lng) async {
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$lat,$lng',
  });
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted) notify(context, 'Google Maps est indisponible.');
}

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.demo});
  final bool demo;
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with LoadData<MapPage> {
  Position? location;
  String? filter;
  bool locating = false;

  @override
  Future<dynamic> load() => api.call(
    location == null
        ? '/centres'
        : '/centres?lat=${location!.latitude}&lng=${location!.longitude}',
  );

  Future<void> gps() async {
    setState(() => locating = true);
    try {
      final position = await locate();
      if (!mounted) return;
      location = position;
      reload();
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> deposit(Map<String, dynamic> centre) async {
    final materials = (centre['materials'] as String).split(',');
    final material = await chooseOption(context, 'Matière déposée', materials);
    if (material == null || !mounted) return;
    try {
      await api.call(
        '/deposits',
        method: 'POST',
        data: {'centre_id': centre['id'], 'material': material},
      );
      if (mounted) {
        notify(
          context,
          'Dépôt enregistré. Le centre peut maintenant le confirmer.',
        );
      }
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Heading(
        'Points de collecte',
        widget.demo
            ? 'Centres fictifs à Tunis · démonstration'
            : 'Vérifiez les matières acceptées et les disponibilités.',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: locating ? null : gps,
            icon: const Icon(Icons.my_location),
            label: Text(locating ? 'Localisation…' : 'Utiliser ma position'),
          ),
          Text(
            location == null
                ? 'Distances estimées depuis le centre de Tunis.'
                : 'Distances à vol d’oiseau depuis votre position.',
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 7,
        runSpacing: 4,
        children: [
          FilterChip(
            label: const Text('Toutes'),
            selected: filter == null,
            onSelected: (_) => setState(() => filter = null),
          ),
          ...categoryIcons.keys.map(
            (name) => FilterChip(
              label: Text(name),
              selected: filter == name,
              onSelected: (selected) =>
                  setState(() => filter = selected ? name : null),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      DataPanel(data, (value) {
        final shown = rows(value)
            .where(
              (centre) =>
                  filter == null ||
                  (centre['materials'] as String).split(',').contains(filter),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shown.isEmpty)
              const Panel(child: Text('Aucun centre pour cette sélection.')),
            if (mapEnabled && shown.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 310,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(shown.first['lat'], shown.first['lng']),
                      zoom: 12,
                    ),
                    markers: shown
                        .map(
                          (centre) => Marker(
                            markerId: MarkerId('${centre['id']}'),
                            position: LatLng(centre['lat'], centre['lng']),
                            infoWindow: InfoWindow(
                              title: centre['name'],
                              snippet: centre['availability'],
                            ),
                          ),
                        )
                        .toSet(),
                  ),
                ),
              ),
            ...shown.map(
              (centre) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.location_on_outlined, color: green),
                        Text(
                          centre['name'],
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Tag(centre['availability']),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text('${centre['address']} · ${centre['km']} km'),
                    Text(
                      (centre['materials'] as String).replaceAll(',', ' · '),
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (!widget.demo || mapEnabled)
                          TextButton.icon(
                            onPressed: () =>
                                openMaps(context, centre['lat'], centre['lng']),
                            icon: const Icon(Icons.directions_outlined),
                            label: const Text('Google Maps'),
                          ),
                        if (centre['availability'] == 'Disponible')
                          TextButton.icon(
                            onPressed: () => deposit(centre),
                            icon: const Icon(Icons.recycling),
                            label: const Text('Déclarer un dépôt'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: SafeArea(child: Deposits(staff: false, back: true)),
                  ),
                ),
              ),
              icon: const Icon(Icons.history),
              label: const Text('Mes dépôts'),
            ),
          ],
        );
      }, reload),
    ],
  );
}

Future<String?> chooseOption(
  BuildContext context,
  String title,
  List<String> options,
) => showModalBottomSheet<String>(
  context: context,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ...options.map(
            (option) => ListTile(
              title: Text(option),
              onTap: () => Navigator.pop(context, option),
            ),
          ),
        ],
      ),
    ),
  ),
);

const reportKinds = [
  'Poubelle pleine',
  'Point endommagé',
  'Dépôt sauvage',
  'Autre problème',
];
const reportStates = ['Reçu', 'Planifié', 'En cours', 'Résolu'];

class Reports extends StatefulWidget {
  const Reports({super.key, this.staff = false});
  final bool staff;
  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> with LoadData<Reports> {
  @override
  Future<dynamic> load() => api.call('/reports');

  Future<void> create() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReportForm()),
    );
    if (result == true && mounted) {
      reload();
      notify(context, 'Signalement enregistré.');
    }
  }

  Future<void> update(int id) async {
    final status = await chooseOption(
      context,
      'État de l’intervention',
      reportStates,
    );
    if (status == null || !mounted) return;
    try {
      await api.call('/reports/$id', method: 'PATCH', data: {'status': status});
      if (mounted) reload();
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Heading(
        widget.staff ? 'Interventions' : 'Mes signalements',
        widget.staff
            ? 'Consultez les demandes et mettez à jour les interventions.'
            : 'Signalez un problème et suivez sa prise en charge.',
      ),
      Wrap(
        spacing: 8,
        children: [
          if (!widget.staff)
            FilledButton.icon(
              onPressed: create,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau signalement'),
            ),
          IconButton(
            onPressed: reload,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 10),
      DataPanel(
        data,
        (value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows(value).isEmpty)
              const Panel(child: Text('Aucun signalement enregistré.')),
            ...rows(value).map(
              (report) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '#${report['id']} · ${report['kind']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Tag(report['status']),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(report['details']),
                    Text(
                      '${report['lat']}, ${report['lng']}',
                      style: const TextStyle(color: muted),
                    ),
                    if (report['has_photo'] == true || report['has_photo'] == 1)
                      TextButton.icon(
                        onPressed: () async {
                          final response = await http
                              .get(
                                Uri.parse(
                                  '${Api.base}/reports/${report['id']}/photo',
                                ),
                                headers: api.headers,
                              )
                              .catchError((Object _) => http.Response('', 503));
                          if (!context.mounted) return;
                          if (response.statusCode != 200) {
                            notify(context, 'Photo indisponible.');
                            return;
                          }
                          showDialog<void>(
                            context: context,
                            builder: (_) => Dialog(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 620,
                                  maxHeight: 600,
                                ),
                                child: Image.memory(response.bodyBytes),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Voir la photo'),
                      ),
                    if (widget.staff)
                      TextButton(
                        onPressed: () => update(report['id']),
                        child: const Text('Modifier l’état'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        reload,
      ),
    ],
  );
}

class ReportForm extends StatefulWidget {
  const ReportForm({super.key});
  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final description = TextEditingController();
  final lat = TextEditingController();
  final lng = TextEditingController();
  String kind = reportKinds.first;
  Uint8List? photo;
  bool busy = false;
  bool locating = false;
  bool picking = false;

  @override
  void dispose() {
    description.dispose();
    lat.dispose();
    lng.dispose();
    super.dispose();
  }

  Future<void> gps() async {
    setState(() => locating = true);
    try {
      final position = await locate();
      if (mounted) {
        setState(() {
          lat.text = position.latitude.toStringAsFixed(6);
          lng.text = position.longitude.toStringAsFixed(6);
        });
      }
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> pick(ImageSource source) async {
    setState(() => picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 4000000) {
        throw StateError('La photo doit faire moins de 4 Mo.');
      }
      if (mounted) setState(() => photo = bytes);
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> send() async {
    final latitude = double.tryParse(lat.text.replaceAll(',', '.'));
    final longitude = double.tryParse(lng.text.replaceAll(',', '.'));
    if (description.text.trim().length < 3 ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      notify(context, 'Renseignez une description et des coordonnées valides.');
      return;
    }
    setState(() => busy = true);
    try {
      await api.call(
        '/reports',
        method: 'POST',
        data: {
          'kind': kind,
          'details': description.text.trim(),
          'lat': latitude,
          'lng': longitude,
          if (photo != null) 'photo': base64Encode(photo!),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nouveau signalement')),
    body: PageBody(
      maxWidth: 660,
      children: [
        DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: const InputDecoration(labelText: 'Type de problème'),
          items: reportKinds
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) => setState(() => kind = value!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLength: 700,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Description du problème',
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: locating ? null : gps,
              icon: const Icon(Icons.my_location),
              label: const Text('Utiliser le GPS'),
            ),
            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: picking ? null : () => pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Prendre une photo'),
              ),
            OutlinedButton.icon(
              onPressed: picking ? null : () => pick(ImageSource.gallery),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Joindre une photo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: lat,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: lng,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        if (photo != null) ...[
          const SizedBox(height: 12),
          Image.memory(photo!, height: 160),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : send,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Envoyer le signalement'),
        ),
      ],
    ),
  );
}

class Deposits extends StatefulWidget {
  const Deposits({super.key, required this.staff, this.back = false});
  final bool staff, back;
  @override
  State<Deposits> createState() => _DepositsState();
}

class _DepositsState extends State<Deposits> with LoadData<Deposits> {
  @override
  Future<dynamic> load() => api.call('/deposits');

  Future<void> confirm(int id) async {
    final verify = await ask(
      context,
      'Confirmer ce dépôt ?',
      'Le citoyen recevra 25 EcoPoints.',
    );
    if (!verify || !mounted) return;
    try {
      await api.call('/deposits/$id/confirm', method: 'POST');
      if (mounted) {
        reload();
        notify(context, 'Dépôt confirmé. 25 EcoPoints crédités.');
      }
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      if (widget.back)
        Align(
          alignment: Alignment.centerLeft,
          child: BackButton(onPressed: () => Navigator.pop(context)),
        ),
      Heading(
        widget.staff ? 'Dépôts à vérifier' : 'Mes dépôts',
        'Les dépôts confirmés rapportent 25 EcoPoints.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: reload,
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh),
        ),
      ),
      DataPanel(
        data,
        (value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows(value).isEmpty)
              const Panel(child: Text('Aucun dépôt enregistré.')),
            ...rows(value).map(
              (deposit) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${deposit['id']} · ${deposit['material']}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(deposit['name']),
                    const SizedBox(height: 6),
                    Tag(deposit['status']),
                    if (widget.staff && deposit['status'] == 'En attente')
                      TextButton(
                        onPressed: () => confirm(deposit['id']),
                        child: const Text('Confirmer le dépôt'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        reload,
      ),
    ],
  );
}

Future<bool> ask(BuildContext context, String title, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ??
    false;

class Rewards extends StatefulWidget {
  const Rewards({
    super.key,
    required this.demo,
    required this.onChanged,
    required this.points,
    this.staff = false,
  });
  final bool demo, staff;
  final int points;
  final Future<void> Function() onChanged;
  @override
  State<Rewards> createState() => _RewardsState();
}

class _RewardsState extends State<Rewards> with LoadData<Rewards> {
  bool busy = false;
  @override
  Future<dynamic> load() => Future.wait([
    api.call('/rewards'),
    if (!widget.staff) api.call('/redemptions'),
  ]);

  Future<void> redeem(Map<String, dynamic> reward) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final verify = await ask(
        context,
        reward['title'],
        'Débiter ${reward['cost']} EcoPoints de votre solde ?',
      );
      if (!verify || !mounted) return;
      final result = await api.call(
        '/rewards/${reward['id']}/redeem',
        method: 'POST',
      );
      if (!mounted) return;
      reload();
      notify(context, 'Code enregistré : ${result['code']}');
      await widget.onChanged();
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const RewardEditor(),
    );
    if (saved == true && mounted) reload();
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Heading(
        widget.staff ? 'Récompenses' : 'Mes EcoPoints',
        widget.demo
            ? 'Catalogue et codes de démonstration.'
            : 'Échangez vos points contre les offres disponibles.',
      ),
      if (!widget.staff)
        Panel(
          color: lime,
          child: Row(
            children: [
              const Icon(Icons.stars_rounded, color: green, size: 32),
              const SizedBox(width: 10),
              Text(
                '${widget.points} EcoPoints',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        )
      else
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une récompense'),
          ),
        ),
      const SizedBox(height: 8),
      DataPanel(
        data,
        (values) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows(values[0]).isEmpty)
              const Panel(child: Text('Aucune récompense disponible.')),
            ...rows(values[0]).map(
              (reward) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(reward['partner']),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Tag('${reward['cost']} EcoPoints'),
                        if (!widget.staff)
                          FilledButton.tonal(
                            onPressed: busy || widget.points < reward['cost']
                                ? null
                                : () => redeem(reward),
                            child: const Text('Échanger'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!widget.staff) ...[
              const SizedBox(height: 9),
              const Text(
                'Mes échanges',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (rows(values[1]).isEmpty)
                const Panel(child: Text('Aucun échange enregistré.')),
              ...rows(values[1]).map(
                (item) => Panel(
                  child: SelectableText('${item['title']} · ${item['code']}'),
                ),
              ),
            ],
          ],
        ),
        reload,
      ),
    ],
  );
}
