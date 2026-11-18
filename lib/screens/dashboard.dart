part of '../main.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.eco_rounded, size: 22, color: lime),
      ),
      const SizedBox(width: 9),
      const Text(
        'EcoVision',
        style: TextStyle(
          fontSize: 23,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.1,
        ),
      ),
    ],
  );
}

class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.wide,
  });
  final IconData icon;
  final String label;
  final bool selected, wide;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: wide ? 14 : 10,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        color: selected ? green : muted,
      ),
    );
    final symbol = Icon(icon, size: 21, color: selected ? green : muted);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: wide ? 0 : 2),
      child: Material(
        color: selected ? pale : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 11,
              horizontal: wide ? 12 : 0,
            ),
            child: wide
                ? Row(
                    children: [
                      symbol,
                      const SizedBox(width: 11),
                      Expanded(child: text),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [symbol, const SizedBox(height: 3), text],
                  ),
          ),
        ),
      ),
    );
  }
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1120});
  final List<Widget> children;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        size.maxWidth >= 700 ? 32 : 17,
        24,
        size.maxWidth >= 700 ? 32 : 17,
        30,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 19),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.15,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: muted)),
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = 17,
    this.color = Colors.white,
  });
  final Widget child;
  final double padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffe3eae2)),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: pale,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: green),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: const TextStyle(
            color: green,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.name,
    required this.points,
    required this.onNavigate,
  });
  final String name;
  final int points;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Heading(
        'Bonjour, ${name.split(' ').first}',
        'Identifiez un déchet ou trouvez un point de collecte près de vous.',
      ),
      LayoutBuilder(
        builder: (context, dimensions) {
          final hero = Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff10392d), Color(0xff1f674d)],
              ),
              borderRadius: BorderRadius.circular(23),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(painter: _HeroRings()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(23),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.document_scanner_outlined,
                        color: lime,
                        size: 30,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Comment trier\nce déchet ?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 33,
                          fontWeight: FontWeight.w900,
                          height: 1.03,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Prenez une photo pour obtenir un conseil de tri.',
                        style: TextStyle(color: Color(0xffdcece1)),
                      ),
                      const SizedBox(height: 17),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: lime,
                          foregroundColor: ink,
                        ),
                        onPressed: () => onNavigate(1),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Scanner un déchet'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
          final wallet = Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              color: const Color(0xffe5efce),
              borderRadius: BorderRadius.circular(23),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.stars_outlined, size: 29, color: green),
                const SizedBox(height: 15),
                const Text(
                  'Mes EcoPoints',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$points',
                  style: const TextStyle(
                    fontSize: 46,
                    height: 1.13,
                    letterSpacing: -2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Consultez les récompenses disponibles avec votre solde.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 9),
                TextButton(
                  onPressed: () => onNavigate(4),
                  child: const Text('Voir les récompenses →'),
                ),
              ],
            ),
          );
          if (dimensions.maxWidth >= 680) {
            return Row(
              children: [
                Expanded(flex: 7, child: hero),
                const SizedBox(width: 15),
                Expanded(flex: 4, child: wallet),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [hero, const SizedBox(height: 12), wallet],
          );
        },
      ),
      const SizedBox(height: 23),
      const Text(
        'Services',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21),
      ),
      const SizedBox(height: 11),
      LayoutBuilder(
        builder: (context, size) {
          final actions = [
            _QuickAction(
              Icons.place_outlined,
              'Points de collecte',
              'Vérifiez les matières acceptées.',
              () => onNavigate(2),
            ),
            _QuickAction(
              Icons.flag_outlined,
              'Signaler un problème',
              'Envoyez et suivez vos signalements.',
              () => onNavigate(3),
            ),
          ];
          return size.maxWidth >= 630
              ? Row(
                  children: [
                    Expanded(child: actions[0]),
                    const SizedBox(width: 12),
                    Expanded(child: actions[1]),
                  ],
                )
              : Column(children: actions);
        },
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Panel(
    padding: 0,
    child: ListTile(
      contentPadding: const EdgeInsets.all(13),
      leading: CircleAvatar(
        backgroundColor: pale,
        foregroundColor: green,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_rounded, size: 18, color: green),
      onTap: onTap,
    ),
  );
}

class _HeroRings extends CustomPainter {
  const _HeroRings();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lime.withValues(alpha: .15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final centre = Offset(size.width * .96, size.height * .42);
    for (final radius in [42.0, 70.0, 98.0, 126.0, 154.0, 182.0]) {
      canvas.drawCircle(centre, radius, paint);
    }
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
      centre.translate(-66, -29),
      6,
      paint..color = lime.withValues(alpha: .7),
    );
    canvas.drawCircle(centre.translate(-102, 73), 4, paint);
  }

  @override
  bool shouldRepaint(_HeroRings oldDelegate) => false;
}
