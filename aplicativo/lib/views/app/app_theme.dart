import 'package:flutter/material.dart';
import 'package:mioamoreapp/helpers/constants.dart';

/// Constantes visuais e listas usadas nas telas do app (núcleo novo, via API).
class AppTheme {
  AppTheme._();
  static const navy = Color(0xFF111D40);
  static Color get gold => AppConstants.primaryColor;
  static const goldHex = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFE9C75A);
  static const bg = Color(0xFFF6F7FB);
  static const surface = Colors.white;

  // Texto (3 níveis — pare de inventar cinza)
  static const textPrimary = navy;
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9AA1B2);

  // Linhas / campos
  static const border = Color(0xFFE7EAF0);
  static const fieldBg = Color(0xFFF0F2F7);

  // Raios padrão
  static const rSm = 12.0;
  static const rMd = 16.0;
  static const rLg = 22.0;
  static const rPill = 28.0;

  // Sombra suave padrão dos cards
  static List<BoxShadow> get softShadow => [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4)),
      ];

  // Estilo do botão primário (dourado)
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: navy,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
      );

  static ButtonStyle get secondaryButton => OutlinedButton.styleFrom(
        foregroundColor: navy,
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
      );
}

/// Cabeçalho padrão das abas principais (mesma altura/título em todas).
class AppTabHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? leading;
  final List<Widget> actions;
  const AppTabHeader({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          if (icon != null) ...[
            Icon(icon, color: AppTheme.gold, size: 24),
            const SizedBox(width: 8),
          ],
          Text(title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy)),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// Título de seção padrão.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.navy));
}

/// Card branco padrão (borda + sombra suave).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, child: box);
  }
}

/// Chip de seleção padrão (dourado/branco) — usado em filtros, edição, etc.
class AppChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const AppChoiceChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.gold : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          border: Border.all(
              color: selected ? AppTheme.gold : AppTheme.border, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppTheme.navy : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}


const kDenominations = [
  "Batista",
  "Católica",
  "Assembleia de Deus",
  "Presbiteriana",
  "Universal",
  "Luterana",
  "Metodista",
  "Adventista",
  "Quadrangular",
  "Outra",
];

const kChurchFrequency = [
  "Mais de uma vez por semana",
  "Toda semana",
  "Às vezes",
  "Raramente",
];

const kIntentions = [
  "Namoro sério",
  "Casamento",
  "Amizade",
];

const kInterests = [
  "Louvor & Adoração",
  "Estudo bíblico",
  "Missões",
  "Música",
  "Esportes",
  "Viagens",
  "Leitura",
  "Culinária",
  "Voluntariado",
  "Família",
  "Cinema",
  "Café",
];

const kInterestEmoji = {
  "Louvor & Adoração": "🎶",
  "Estudo bíblico": "📖",
  "Missões": "✝️",
  "Música": "🎵",
  "Esportes": "⚽",
  "Viagens": "✈️",
  "Leitura": "📚",
  "Culinária": "🍳",
  "Voluntariado": "🤝",
  "Família": "👨‍👩‍👧",
  "Cinema": "🎬",
  "Café": "☕",
};

/// Ícone (vetor) para cada interesse — usado nos chips do perfil.
const Map<String, IconData> kInterestIcon = {
  "Louvor & Adoração": Icons.library_music_rounded,
  "Estudo bíblico": Icons.menu_book_rounded,
  "Missões": Icons.public_rounded,
  "Música": Icons.music_note_rounded,
  "Esportes": Icons.sports_soccer_rounded,
  "Viagens": Icons.flight_takeoff_rounded,
  "Leitura": Icons.auto_stories_rounded,
  "Culinária": Icons.restaurant_rounded,
  "Voluntariado": Icons.volunteer_activism_rounded,
  "Família": Icons.family_restroom_rounded,
  "Cinema": Icons.movie_rounded,
  "Café": Icons.local_cafe_rounded,
};

IconData interestIcon(String interest) =>
    kInterestIcon[interest] ?? Icons.local_offer_rounded;

/// Rótulo de presença a partir de isOnline + lastActiveAt (ISO).
/// Retorna "online", "online recentemente" ou null (offline).
String? onlineLabel(dynamic isOnline, dynamic lastActiveAt) {
  if (isOnline == true) return "online";
  if (lastActiveAt != null) {
    final t = DateTime.tryParse(lastActiveAt.toString());
    if (t != null && DateTime.now().difference(t).inHours < 24) {
      return "online recentemente";
    }
  }
  return null;
}

/// Texto detalhado de presença para o cabeçalho do chat.
/// Online → "Online"; offline → "visto há X min/h" e, após 24h, data e hora.
String presenceText(dynamic isOnline, dynamic lastActiveAt) {
  if (isOnline == true) return "Online";
  final t =
      lastActiveAt != null ? DateTime.tryParse(lastActiveAt.toString()) : null;
  if (t == null) return "Offline";
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return "visto agora mesmo";
  if (diff.inMinutes < 60) return "visto há ${diff.inMinutes} min";
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return "visto há $h ${h == 1 ? 'hora' : 'horas'}";
  }
  String two(int n) => n.toString().padLeft(2, '0');
  final data = "${two(t.day)}/${two(t.month)}";
  final hora = "${two(t.hour)}:${two(t.minute)}";
  return "visto em $data às $hora";
}
