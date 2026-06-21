import 'package:flutter/material.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';

/// Filtros da descoberta.
class DiscoverFilters {
  int minAge;
  int maxAge;
  double maxDistanceKm; // se anyDistance, ignora
  bool anyDistance;
  String? gender; // MALE/FEMALE/OTHER ou null (todos)
  Set<String> denominations;
  Set<String> interests;
  String? intention; // VIP
  String? churchFrequency; // VIP

  DiscoverFilters({
    this.minAge = 18,
    this.maxAge = 70,
    this.maxDistanceKm = 200,
    this.anyDistance = true,
    this.gender,
    Set<String>? denominations,
    Set<String>? interests,
    this.intention,
    this.churchFrequency,
  })  : denominations = denominations ?? {},
        interests = interests ?? {};

  Map<String, String> toQuery() {
    final q = <String, String>{
      "minAge": minAge.toString(),
      "maxAge": maxAge.toString(),
    };
    if (!anyDistance) q["maxDistanceKm"] = maxDistanceKm.round().toString();
    if (gender != null) q["gender"] = gender!;
    if (denominations.isNotEmpty) q["denominations"] = denominations.join(",");
    if (interests.isNotEmpty) q["interests"] = interests.join(",");
    if (intention != null) q["intention"] = intention!;
    if (churchFrequency != null) q["churchFrequency"] = churchFrequency!;
    return q;
  }

  DiscoverFilters copy() => DiscoverFilters(
        minAge: minAge,
        maxAge: maxAge,
        maxDistanceKm: maxDistanceKm,
        anyDistance: anyDistance,
        gender: gender,
        denominations: {...denominations},
        interests: {...interests},
        intention: intention,
        churchFrequency: churchFrequency,
      );
}

class FiltersPage extends StatefulWidget {
  final DiscoverFilters filters;
  const FiltersPage({super.key, required this.filters});

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  late DiscoverFilters f = widget.filters.copy();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0.5,
        title: const Text("Filtros"),
        actions: [
          TextButton(
            onPressed: () => setState(() => f = DiscoverFilters()),
            child: const Text("Limpar", style: TextStyle(color: Color(0xFF7A849C))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _title("Sexo"),
          Wrap(spacing: 8, children: [
            _genderChip("Todos", null),
            _genderChip("Masculino", "MALE"),
            _genderChip("Feminino", "FEMALE"),
            _genderChip("Outro", "OTHER"),
          ]),
          const SizedBox(height: 22),
          Row(children: [
            _title("Idade"),
            const Spacer(),
            Text("${f.minAge} - ${f.maxAge}",
                style: const TextStyle(
                    color: AppTheme.navy, fontWeight: FontWeight.bold)),
          ]),
          RangeSlider(
            values: RangeValues(f.minAge.toDouble(), f.maxAge.toDouble()),
            min: 18,
            max: 80,
            divisions: 62,
            activeColor: AppTheme.gold,
            labels: RangeLabels("${f.minAge}", "${f.maxAge}"),
            onChanged: (v) => setState(() {
              f.minAge = v.start.round();
              f.maxAge = v.end.round();
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _title("Distância"),
            const Spacer(),
            Text(f.anyDistance ? "Qualquer" : "${f.maxDistanceKm.round()} km",
                style: const TextStyle(
                    color: AppTheme.navy, fontWeight: FontWeight.bold)),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.gold,
            title: const Text("Qualquer distância"),
            value: f.anyDistance,
            onChanged: (v) => setState(() => f.anyDistance = v),
          ),
          if (!f.anyDistance)
            Slider(
              value: f.maxDistanceKm,
              min: 5,
              max: 500,
              divisions: 99,
              activeColor: AppTheme.gold,
              label: "${f.maxDistanceKm.round()} km",
              onChanged: (v) => setState(() => f.maxDistanceKm = v),
            ),
          const SizedBox(height: 14),
          _title("Denominações"),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in kDenominations) _multiChip(d, f.denominations),
          ]),
          const SizedBox(height: 22),
          _title("Interesses"),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final i in kInterests) _multiChip(i, f.interests),
          ]),
          const SizedBox(height: 22),
          _title("Intenção  ⭐ VIP"),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final it in kIntentions) _singleChip(it, f.intention,
                (v) => setState(() => f.intention = v)),
          ]),
          const SizedBox(height: 22),
          _title("Frequência à igreja  ⭐ VIP"),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in kChurchFrequency) _singleChip(c, f.churchFrequency,
                (v) => setState(() => f.churchFrequency = v)),
          ]),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, f),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text("Aplicar filtros",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.navy)),
      );

  Widget _genderChip(String label, String? value) {
    return AppChoiceChip(
      label: label,
      selected: f.gender == value,
      onTap: () => setState(() => f.gender = value),
    );
  }

  Widget _multiChip(String label, Set<String> set) {
    return AppChoiceChip(
      label: label,
      selected: set.contains(label),
      onTap: () =>
          setState(() => set.contains(label) ? set.remove(label) : set.add(label)),
    );
  }

  Widget _singleChip(String label, String? current, void Function(String?) onPick) {
    final selected = current == label;
    return AppChoiceChip(
      label: label,
      selected: selected,
      onTap: () => onPick(selected ? null : label),
    );
  }
}
