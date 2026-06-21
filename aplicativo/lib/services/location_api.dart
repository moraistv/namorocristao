import 'dart:convert';
import 'package:http/http.dart' as http;

class Country {
  final String name;
  final String code; // cca2
  final String flag; // emoji
  Country(this.name, this.code, this.flag);
}

class StateUf {
  final String sigla;
  final String nome;
  StateUf(this.sigla, this.nome);
}

/// APIs públicas de localização (sem chave): restcountries, IBGE, ViaCEP.
class LocationApi {
  LocationApi._();
  static const _t = Duration(seconds: 15);

  /// Lista de países (nome em PT + bandeira emoji). Brasil primeiro.
  static Future<List<Country>> countries() async {
    try {
      final res = await http
          .get(Uri.parse(
              "https://restcountries.com/v3.1/all?fields=name,translations,flag,cca2"))
          .timeout(_t);
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((c) {
              final pt = c["translations"]?["por"]?["common"];
              final name = (pt ?? c["name"]?["common"] ?? "").toString();
              return Country(
                  name, (c["cca2"] ?? "").toString(), (c["flag"] ?? "🌎").toString());
            })
            .where((c) => c.name.isNotEmpty)
            .toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        // Brasil no topo.
        final idx = list.indexWhere((c) => c.code == "BR");
        if (idx > 0) {
          final br = list.removeAt(idx);
          list.insert(0, br);
        }
        return list;
      }
    } catch (_) {}
    // Fallback mínimo se a API falhar.
    return [
      Country("Brasil", "BR", "🇧🇷"),
      Country("Portugal", "PT", "🇵🇹"),
      Country("Estados Unidos", "US", "🇺🇸"),
    ];
  }

  /// Estados do Brasil (IBGE).
  static Future<List<StateUf>> brStates() async {
    try {
      final res = await http
          .get(Uri.parse(
              "https://servicodados.ibge.gov.br/api/v1/localidades/estados?orderBy=nome"))
          .timeout(_t);
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List)
            .map((e) => StateUf(e["sigla"].toString(), e["nome"].toString()))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Cidades de um estado do Brasil (IBGE).
  static Future<List<String>> brCities(String uf) async {
    try {
      final res = await http
          .get(Uri.parse(
              "https://servicodados.ibge.gov.br/api/v1/localidades/estados/$uf/municipios?orderBy=nome"))
          .timeout(_t);
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List)
            .map((e) => e["nome"].toString())
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Busca por CEP (ViaCEP) → { uf, localidade } ou null.
  static Future<Map<String, String>?> lookupCep(String cep) async {
    final digits = cep.replaceAll(RegExp(r"\D"), "");
    if (digits.length != 8) return null;
    try {
      final res = await http
          .get(Uri.parse("https://viacep.com.br/ws/$digits/json/"))
          .timeout(_t);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j["erro"] == true) return null;
        return {
          "uf": (j["uf"] ?? "").toString(),
          "localidade": (j["localidade"] ?? "").toString(),
        };
      }
    } catch (_) {}
    return null;
  }
}
