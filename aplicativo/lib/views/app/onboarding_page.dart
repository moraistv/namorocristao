import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/location_api.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/main_shell.dart';
import 'package:mioamoreapp/views/app/widgets/searchable_sheet.dart';

const _genderOptions = [
  {"value": "MALE", "label": "Masculino"},
  {"value": "FEMALE", "label": "Feminino"},
  {"value": "OTHER", "label": "Outro"},
];

/// Formata a digitação como DD/MM/AAAA.
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final digits = newV.text.replaceAll(RegExp(r"\D"), "");
    final b = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) b.write("/");
      b.write(digits[i]);
    }
    return TextEditingValue(
      text: b.toString(),
      selection: TextSelection.collapsed(offset: b.length),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pager = PageController();
  int _step = 0;
  static const _totalSteps = 7;

  // Dados
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final List<String> _photos = [];
  String? _gender;
  DateTime? _birthday;
  final _birthdayText = TextEditingController();

  Country? _country;
  StateUf? _stateUf; // para BR
  final _stateText = TextEditingController(); // outros países
  String? _city;
  final _cityText = TextEditingController(); // outros países
  List<StateUf> _states = [];

  String? _denomination;
  String? _frequency;
  String? _intention;
  final Set<String> _interests = {};
  final _about = TextEditingController();

  bool get _isBR => _country?.code == "BR";

  @override
  void initState() {
    super.initState();
    _country = Country("Brasil", "BR", "🇧🇷");
    _loadStates();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _birthdayText.dispose();
    _stateText.dispose();
    _cityText.dispose();
    _about.dispose();
    _pager.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    _states = await LocationApi.brStates();
    if (mounted) setState(() {});
  }

  // ───────── navegação ─────────
  void _next() {
    if (!_validateStep()) return;
    if (_step == _totalSteps - 1) {
      _save();
      return;
    }
    _pager.nextPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
  }

  void _back() {
    if (_step == 0) {
      Navigator.maybePop(context);
      return;
    }
    _pager.previousPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
  }

  DateTime? _parseTypedDate(String s) {
    final m = RegExp(r"^(\d{2})/(\d{2})/(\d{4})$").firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final y = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    try {
      final date = DateTime(y, mo, d);
      if (date.day != d || date.month != mo) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  int _ageOf(DateTime b) {
    final now = DateTime.now();
    int a = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
    return a;
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_firstName.text.trim().length < 2) {
          EasyLoading.showError("Informe seu nome");
          return false;
        }
        if (_lastName.text.trim().length < 2) {
          EasyLoading.showError("Informe seu sobrenome");
          return false;
        }
        return true;
      case 1:
        if (_photos.isEmpty) {
          EasyLoading.showError("Adicione ao menos 1 foto sua");
          return false;
        }
        return true;
      case 2:
        if (_gender == null) {
          EasyLoading.showError("Selecione o gênero");
          return false;
        }
        final typed = _parseTypedDate(_birthdayText.text.trim());
        if (typed != null) _birthday = typed;
        if (_birthday == null) {
          EasyLoading.showError("Informe a data de nascimento (DD/MM/AAAA)");
          return false;
        }
        if (_ageOf(_birthday!) < 18) {
          EasyLoading.showError("É necessário ter ao menos 18 anos");
          return false;
        }
        return true;
      case 3:
        if (_country == null) {
          EasyLoading.showError("Selecione o país");
          return false;
        }
        final city = _isBR ? _city : _cityText.text.trim();
        if (city == null || city.isEmpty) {
          EasyLoading.showError("Informe a cidade");
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _save() async {
    final city = _isBR ? _city : _cityText.text.trim();
    final stateName = _isBR ? _stateUf?.sigla : _stateText.text.trim();
    final addressParts = [
      if (city != null && city.isNotEmpty) city,
      if (stateName != null && stateName.isNotEmpty) stateName,
      _country?.name,
    ].whereType<String>();

    EasyLoading.show(status: "Salvando...");
    try {
      await AppApi.upsertProfile({
        "fullName": "${_firstName.text.trim()} ${_lastName.text.trim()}",
        "gender": _gender,
        "birthday": _birthday!.toIso8601String(),
        "city": city,
        "addressText": addressParts.join(" - "),
        "denomination": _denomination,
        "churchFrequency": _frequency,
        "intention": _intention,
        "interests": _interests.toList(),
        "about": _about.text.trim().isEmpty ? null : _about.text.trim(),
        "mediaFiles": _photos,
        "profilePicture": _photos.isNotEmpty ? _photos.first : null,
      });
      EasyLoading.dismiss();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (r) => false,
      );
    } on AppApiException catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(e.message);
    }
  }

  // ───────── seleção de localização ─────────
  Future<void> _pickCountry() async {
    EasyLoading.show(status: "Carregando países...");
    final list = await LocationApi.countries();
    EasyLoading.dismiss();
    if (!mounted) return;
    final c = await showSearchableSheet<Country>(
      context: context,
      title: "Selecione o país",
      items: list,
      label: (c) => c.name,
      prefix: (c) => c.flag,
    );
    if (c != null) {
      setState(() {
        _country = c;
        _stateUf = null;
        _city = null;
        _cityText.clear();
        _stateText.clear();
      });
      if (c.code == "BR" && _states.isEmpty) _loadStates();
    }
  }

  Future<void> _pickState() async {
    if (_states.isEmpty) {
      EasyLoading.show(status: "Carregando estados...");
      await _loadStates();
      EasyLoading.dismiss();
    }
    if (!mounted) return;
    final s = await showSearchableSheet<StateUf>(
      context: context,
      title: "Selecione o estado",
      items: _states,
      label: (s) => "${s.nome} (${s.sigla})",
    );
    if (s != null) {
      setState(() {
        _stateUf = s;
        _city = null;
      });
    }
  }

  Future<void> _pickCity() async {
    if (_stateUf == null) {
      EasyLoading.showError("Selecione o estado primeiro");
      return;
    }
    EasyLoading.show(status: "Carregando cidades...");
    final cities = await LocationApi.brCities(_stateUf!.sigla);
    EasyLoading.dismiss();
    if (!mounted) return;
    final c = await showSearchableSheet<String>(
      context: context,
      title: "Selecione a cidade",
      items: cities,
      label: (c) => c,
    );
    if (c != null) setState(() => _city = c);
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 6) {
      EasyLoading.showError("Máximo de 6 fotos");
      return;
    }
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 75,
      );
      if (file == null) return;
      EasyLoading.show(status: "Enviando foto...");
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final ext = file.name.split(".").last.toLowerCase();
      final url = await AppApi.uploadPhoto(b64, ext: ext == "png" ? "png" : "jpg");
      setState(() => _photos.add(url));
      EasyLoading.dismiss();
    } on AppApiException catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(e.message);
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Não foi possível enviar a foto");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Topo: voltar + progresso
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back, color: AppTheme.navy),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _totalSteps,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE6E9F0),
                        valueColor: AlwaysStoppedAnimation(AppTheme.gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text("${_step + 1}/$_totalSteps",
                      style: const TextStyle(
                          color: AppTheme.navy, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _stepName(),
                  _stepPhotos(),
                  _stepGenderBirthday(),
                  _stepLocation(),
                  _stepFaith(),
                  _stepInterests(),
                  _stepAbout(),
                ],
              ),
            ),
            // Botão continuar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.navy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_step == _totalSteps - 1 ? "Concluir" : "Continuar",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── widgets de step ─────────
  Widget _stepWrapper(String title, String subtitle, List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.navy)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF7A849C), fontSize: 14)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _dec(String hint, [IconData? icon]) => InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E3EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E3EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.gold, width: 1.5),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.navy, fontSize: 15)),
      );

  Widget _selectField(String value, String placeholder, VoidCallback onTap,
      {String? prefix}) {
    final has = value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E3EB)),
        ),
        child: Row(
          children: [
            if (prefix != null && prefix.isNotEmpty) ...[
              Text(prefix, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(has ? value : placeholder,
                  style: TextStyle(
                      color: has ? AppTheme.navy : const Color(0xFF9AA1B2),
                      fontSize: 15)),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9AA1B2)),
          ],
        ),
      ),
    );
  }

  Widget _chips(List<String> options, String? selected, void Function(String) onTap,
      {bool multi = false, Set<String>? set}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final sel = multi ? set!.contains(o) : selected == o;
        return GestureDetector(
          onTap: () => onTap(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: sel ? AppTheme.gold : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: sel ? AppTheme.gold : const Color(0xFFE0E3EB), width: 1.5),
            ),
            child: Text(o,
                style: TextStyle(
                    color: sel ? AppTheme.navy : const Color(0xFF555B6E),
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  Widget _stepName() => _stepWrapper("Como te chamam?", "Seu nome aparecerá no perfil.", [
        _label("Nome"),
        TextField(controller: _firstName, decoration: _dec("Seu nome", Icons.person_outline)),
        _label("Sobrenome"),
        TextField(controller: _lastName, decoration: _dec("Seu sobrenome", Icons.badge_outlined)),
      ]);

  Widget _stepPhotos() => _stepWrapper(
        "Suas fotos",
        "Pelo menos 1 foto sua (ajuda a evitar perfis falsos). Até 6.",
        [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              ..._photos.asMap().entries.map((e) => _photoTile(e.key, e.value)),
              if (_photos.length < 6) _addPhotoTile(),
            ],
          ),
        ],
      );

  Widget _photoTile(int index, String url) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _photos.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
            if (index == 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppTheme.gold,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: const Text("Principal",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      );

  Widget _addPhotoTile() => GestureDetector(
        onTap: _addPhoto,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.gold, width: 1.5),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: AppTheme.gold, size: 28),
                const SizedBox(height: 4),
                const Text("Adicionar",
                    style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

  Widget _stepGenderBirthday() =>
      _stepWrapper("Sobre você", "Gênero e data de nascimento.", [
        _label("Gênero"),
        _chips(
          _genderOptions.map((g) => g["label"]!).toList(),
          _genderOptions.firstWhere((g) => g["value"] == _gender,
              orElse: () => {"label": ""})["label"],
          (label) => setState(() => _gender =
              _genderOptions.firstWhere((g) => g["label"] == label)["value"]),
        ),
        _label("Data de nascimento"),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _birthdayText,
                keyboardType: TextInputType.number,
                inputFormatters: [_DateInputFormatter()],
                decoration: _dec("DD/MM/AAAA", Icons.cake_outlined),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthday ?? DateTime(now.year - 22),
                  firstDate: DateTime(now.year - 80),
                  lastDate: DateTime(now.year - 18, now.month, now.day),
                  locale: const Locale("pt", "BR"),
                );
                if (picked != null) {
                  setState(() {
                    _birthday = picked;
                    _birthdayText.text =
                        "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                  });
                }
              },
              style: IconButton.styleFrom(
                  backgroundColor: AppTheme.navy, foregroundColor: Colors.white),
              icon: const Icon(Icons.calendar_month),
            ),
          ],
        ),
      ]);

  Widget _stepLocation() =>
      _stepWrapper("Onde você está?", "País, estado e cidade.", [
        _label("País"),
        _selectField(_country?.name ?? "", "Selecione o país", _pickCountry,
            prefix: _country?.flag),
        if (_isBR) ...[
          _label("Estado"),
          _selectField(_stateUf == null ? "" : "${_stateUf!.nome} (${_stateUf!.sigla})",
              "Selecione o estado", _pickState),
          _label("Cidade"),
          _selectField(_city ?? "", "Selecione a cidade", _pickCity),
        ] else ...[
          _label("Estado/Região"),
          TextField(controller: _stateText, decoration: _dec("Seu estado/região")),
          _label("Cidade"),
          TextField(controller: _cityText, decoration: _dec("Sua cidade")),
        ],
      ]);

  Widget _stepFaith() => _stepWrapper("Sua fé", "Conte sobre sua caminhada cristã.", [
        _label("Denominação"),
        _chips(kDenominations, _denomination, (v) => setState(() => _denomination = v)),
        _label("Frequência à igreja"),
        _chips(kChurchFrequency, _frequency, (v) => setState(() => _frequency = v)),
        _label("O que você procura?"),
        _chips(kIntentions, _intention, (v) => setState(() => _intention = v)),
      ]);

  Widget _stepInterests() =>
      _stepWrapper("Interesses", "Escolha até 5 (ajuda no match).", [
        _chips(kInterests, null, (v) {
          setState(() {
            if (_interests.contains(v)) {
              _interests.remove(v);
            } else if (_interests.length < 5) {
              _interests.add(v);
            }
          });
        }, multi: true, set: _interests),
      ]);

  Widget _stepAbout() => _stepWrapper("Sobre você", "Uma bio curta (opcional).", [
        TextField(
          controller: _about,
          maxLines: 5,
          decoration: _dec("Fale um pouco sobre você e sua fé..."),
        ),
      ]);
}
