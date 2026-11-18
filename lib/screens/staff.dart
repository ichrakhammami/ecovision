part of '../main.dart';

class CentreAdmin extends StatefulWidget {
  const CentreAdmin({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  State<CentreAdmin> createState() => _CentreAdminState();
}

class _CentreAdminState extends State<CentreAdmin> with LoadData<CentreAdmin> {
  @override
  Future<dynamic> load() => api.call('/centres');

  Future<void> edit([Map<String, dynamic>? centre]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CentreEditor(centre: centre),
    );
    if (saved == true && mounted) reload();
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Heading(
        'Centres de collecte',
        'Gérez les matières acceptées et la disponibilité.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un centre'),
        ),
      ),
      const SizedBox(height: 12),
      DataPanel(data, (value) {
        final centres = rows(value)
            .where(
              (centre) =>
                  widget.user['role'] == 'admin' ||
                  centre['owner_id'] == widget.user['id'],
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (centres.isEmpty)
              const Panel(child: Text('Aucun centre associé à votre compte.')),
            ...centres.map(
              (centre) => Panel(
                padding: 3,
                child: ListTile(
                  title: Text(
                    centre['name'],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${centre['address']} · ${centre['availability']}\n${centre['materials']}',
                  ),
                  trailing: IconButton(
                    onPressed: () => edit(centre),
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
            ),
          ],
        );
      }, reload),
    ],
  );
}

class CentreEditor extends StatefulWidget {
  const CentreEditor({super.key, this.centre});
  final Map<String, dynamic>? centre;
  @override
  State<CentreEditor> createState() => _CentreEditorState();
}

class _CentreEditorState extends State<CentreEditor> {
  late final fields = {
    for (final key in ['name', 'address', 'lat', 'lng'])
      key: TextEditingController(text: widget.centre?[key]?.toString() ?? ''),
  };
  late final materials = (widget.centre?['materials'] as String? ?? '')
      .split(',')
      .where((v) => v.isNotEmpty)
      .toSet();
  late String availability = widget.centre?['availability'] ?? 'Disponible';
  bool busy = false;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final lat = double.tryParse(fields['lat']!.text.replaceAll(',', '.'));
    final lng = double.tryParse(fields['lng']!.text.replaceAll(',', '.'));
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        materials.isEmpty) {
      notify(context, 'Renseignez des coordonnées et au moins une matière.');
      return;
    }
    setState(() => busy = true);
    try {
      await api.call(
        '/centres/${widget.centre?['id'] ?? 0}',
        method: 'PUT',
        data: {
          'name': fields['name']!.text.trim(),
          'address': fields['address']!.text.trim(),
          'lat': lat,
          'lng': lng,
          'materials': materials.join(','),
          'availability': availability,
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.centre == null ? 'Ajouter un centre' : 'Modifier le centre',
    ),
    scrollable: true,
    content: SizedBox(
      width: 475,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (key, label) in [
            ('name', 'Nom'),
            ('address', 'Adresse'),
            ('lat', 'Latitude'),
            ('lng', 'Longitude'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: fields[key],
                decoration: InputDecoration(labelText: label),
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: availability,
            decoration: const InputDecoration(labelText: 'Disponibilité'),
            items: ['Disponible', 'Complet', 'Fermé']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => availability = value!),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            children: categoryIcons.keys
                .map(
                  (value) => FilterChip(
                    label: Text(value),
                    selected: materials.contains(value),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        materials.add(value);
                      } else {
                        materials.remove(value);
                      }
                    }),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class RewardEditor extends StatefulWidget {
  const RewardEditor({super.key});
  @override
  State<RewardEditor> createState() => _RewardEditorState();
}

class _RewardEditorState extends State<RewardEditor> {
  final title = TextEditingController();
  final partner = TextEditingController();
  final cost = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    partner.dispose();
    cost.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final amount = int.tryParse(cost.text);
    if (amount == null || amount <= 0) {
      notify(context, 'Saisissez un nombre de points positif.');
      return;
    }
    setState(() => busy = true);
    try {
      await api.call(
        '/rewards',
        method: 'POST',
        data: {
          'title': title.text.trim(),
          'partner': partner.text.trim(),
          'cost': amount,
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajouter une récompense'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Nom de l’offre'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: partner,
          decoration: const InputDecoration(labelText: 'Partenaire'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: cost,
          decoration: const InputDecoration(labelText: 'Coût en EcoPoints'),
          keyboardType: TextInputType.number,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: busy ? null : save, child: const Text('Créer')),
    ],
  );
}

class Admin extends StatefulWidget {
  const Admin({super.key, required this.demo, required this.userId});
  final bool demo;
  final int userId;
  @override
  State<Admin> createState() => _AdminState();
}

class _AdminState extends State<Admin> with LoadData<Admin> {
  @override
  Future<dynamic> load() => api.call('/admin');

  Future<void> edit(Map<String, dynamic> user) async {
    final role = await chooseOption(
      context,
      'Rôle de ${user['name']}',
      roles.values.toList(),
    );
    if (role == null || !mounted) return;
    try {
      await api.call(
        '/users/${user['id']}/${roles.entries.firstWhere((item) => item.value == role).key}',
        method: 'PATCH',
      );
      if (mounted) reload();
    } catch (e) {
      if (mounted) notify(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Heading(
        'Administration',
        'Suivez les activités de recyclage et gérez les accès.',
      ),
      DataPanel(data, (value) {
        final counts = Map<String, dynamic>.from(value['counts']);
        const symbols = {
          'centres': Icons.place_outlined,
          'signalements': Icons.flag_outlined,
          'recyclages': Icons.recycling,
          'échanges': Icons.stars_outlined,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: counts.entries
                  .map(
                    (entry) => SizedBox(
                      width: 145,
                      child: Panel(
                        color: pale,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(symbols[entry.key], color: green),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(entry.key),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 13),
            const Text(
              'Utilisateurs',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...rows(value['users']).map(
              (user) => Panel(
                padding: 3,
                child: ListTile(
                  title: Text(
                    user['name'],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${user['email']} · ${roles[user['role']]}'),
                  trailing: IconButton(
                    tooltip: 'Modifier le rôle',
                    onPressed:
                        user['id'] == widget.userId ||
                            (widget.demo &&
                                (user['email'] as String).endsWith(
                                  '@ecovision.local',
                                ))
                        ? null
                        : () => edit(user),
                    icon: const Icon(Icons.manage_accounts_outlined),
                  ),
                ),
              ),
            ),
          ],
        );
      }, reload),
    ],
  );
}
