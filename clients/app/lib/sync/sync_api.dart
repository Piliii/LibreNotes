import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:notally_core/notally_core.dart';

/// Thrown for non-2xx responses that aren't an expected 409 conflict.
class SyncException implements Exception {
  final int status;
  final String body;
  SyncException(this.status, this.body);
  @override
  String toString() => 'SyncException($status): $body';
}

/// Typed HTTP client for the Notally sync server. Mirrors the server routes;
/// 409s are surfaced as a [PushResult] with [PushStatus.conflict], not thrown.
class SyncApi {
  SyncApi({required String baseUrl, required this.token, http.Client? client})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  Map<String, String> get _headers => {
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      };

  Future<bool> health() async {
    final r = await _client.get(Uri.parse('$baseUrl/health'));
    return r.statusCode == 200;
  }

  Future<ChangesResponse> changes(int since) async {
    final r = await _client.get(
      Uri.parse('$baseUrl/changes?since=$since'),
      headers: _headers,
    );
    _ensure2xx(r);
    return ChangesResponse.fromJson(_decode(r));
  }

  Future<PushResult> push(String id, PushRequest req) async {
    final r = await _client.put(
      Uri.parse('$baseUrl/notes/$id'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    if (r.statusCode != 200 && r.statusCode != 409) _ensure2xx(r);
    return PushResult.fromJson(_decode(r));
  }

  Future<void> purgeNote(String id) async {
    final r = await _client.delete(
      Uri.parse('$baseUrl/notes/$id/purge'),
      headers: _headers,
    );
    _ensure2xx(r);
  }

  Future<PushResult> deleteNote(String id, int baseRev) async {
    final r = await _client.delete(
      Uri.parse('$baseUrl/notes/$id?baseRev=$baseRev'),
      headers: _headers,
    );
    if (r.statusCode != 200 && r.statusCode != 409) _ensure2xx(r);
    return PushResult.fromJson(_decode(r));
  }

  Future<Keystore?> getKeystore() async {
    final r = await _client.get(Uri.parse('$baseUrl/keystore'), headers: _headers);
    if (r.statusCode == 404) return null;
    _ensure2xx(r);
    return Keystore.fromJson(_decode(r));
  }

  Future<void> putKeystore(Keystore ks) async {
    final r = await _client.put(
      Uri.parse('$baseUrl/keystore'),
      headers: _headers,
      body: jsonEncode(ks.toJson()),
    );
    _ensure2xx(r);
  }

  void close() => _client.close();

  Map<String, dynamic> _decode(http.Response r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  void _ensure2xx(http.Response r) {
    if (r.statusCode ~/ 100 != 2) throw SyncException(r.statusCode, r.body);
  }
}
