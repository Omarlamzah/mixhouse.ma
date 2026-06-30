part of '../main.dart';

class Api {
  String? token;
  Map<String, String> get headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final uri = Uri.parse('$apiUrl$path');
    final stopwatch = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint('🌐 $method $uri');
    }
    late http.Response r;
    try {
      if (method == 'POST') {
        r = await http.post(uri, headers: headers, body: jsonEncode(body));
      } else if (method == 'PUT') {
        r = await http.put(uri, headers: headers, body: jsonEncode(body));
      } else if (method == 'DELETE') {
        r = await http.delete(uri, headers: headers);
      } else {
        r = await http.get(uri, headers: headers);
      }
    } catch (error) {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('❌ $method $uri • ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('   $error');
      }
      rethrow;
    }
    stopwatch.stop();
    if (kDebugMode) {
      final symbol = r.statusCode >= 200 && r.statusCode < 300 ? '✅' : '❌';
      debugPrint(
        '$symbol ${r.statusCode} $method $uri • ${stopwatch.elapsedMilliseconds}ms • ${r.bodyBytes.length} bytes',
      );
    }
    dynamic data;
    try {
      data = jsonDecode(r.body);
    } catch (_) {
      data = {'message': 'Server returned an invalid response'};
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(
        data is Map ? (data['message'] ?? 'Request failed') : 'Request failed',
      );
    }
    return data;
  }

  Future<dynamic> multipart(
    String path, {
    required Map<String, String> fields,
    Map<String, XFile?> files = const {},
    bool update = false,
  }) async {
    final uri = Uri.parse('$apiUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    request.fields.addAll(fields);
    if (update) request.fields['_method'] = 'PUT';
    for (final entry in files.entries) {
      final file = entry.value;
      if (file == null) continue;
      request.files.add(
        http.MultipartFile.fromBytes(
          entry.key,
          await file.readAsBytes(),
          filename: file.name,
        ),
      );
    }
    if (kDebugMode) debugPrint('🌐 MULTIPART $uri');
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = {'message': 'Server returned an invalid response'};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map ? data['message'] ?? 'Upload failed' : 'Upload failed',
      );
    }
    return data;
  }
}

class User {
  final int id;
  final String name, email, role;
  const User(this.id, this.name, this.email, this.role);
  factory User.from(Map m) => User(
    m['id'] ?? 0,
    m['name'] ?? '',
    m['email'] ?? '',
    m['role'] ?? 'staff',
  );
}

class Session extends ChangeNotifier {
  final api = Api();
  User? user;
  bool loading = true;
  String? authError;
  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    api.token = p.getString('token');
    if (api.token != null) {
      try {
        user = User.from(await api.request('/me'));
      } catch (_) {
        await p.remove('token');
        api.token = null;
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final d = await api.request(
      '/login',
      method: 'POST',
      body: {'email': email, 'password': password},
    );
    api.token = d['token'];
    user = User.from(d['user']);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', api.token!);
    notifyListeners();
  }

  Future<void> completeGoogleLogin(Uri uri) async {
    final error = uri.queryParameters['error'];
    if (error != null) {
      authError = switch (error) {
        'pending_approval' =>
          'Your account is waiting for administrator approval.',
        _ => 'Google sign-in failed. Please try again.',
      };
      notifyListeners();
      return;
    }
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      authError = 'Google did not return a login token.';
      notifyListeners();
      return;
    }
    try {
      api.token = token;
      user = User.from(await api.request('/me'));
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('token', token);
      authError = null;
      notifyListeners();
    } catch (_) {
      api.token = null;
      authError = 'Could not complete Google sign-in.';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await api.request('/logout', method: 'POST');
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    api.token = null;
    user = null;
    notifyListeners();
  }
}
