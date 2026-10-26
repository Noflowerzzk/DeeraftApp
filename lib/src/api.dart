import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

const defaultApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://mc.ainfinitythecoder.cn',
);
const demoBuild = bool.fromEnvironment('DEMO_MODE');

String normalizeOrigin(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      !(uri.scheme == 'https' ||
          (uri.scheme == 'http' && uri.host == 'mc.ainfinitythecoder.cn')) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const FormatException('请输入 HTTPS 地址或现有 Deeraft HTTP 地址，不包含路径');
  }
  return uri.replace(path: '').toString();
}

String randomSecret() => base64Url
    .encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)))
    .replaceAll('=', '');
String pkceChallenge(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.unauthorized = false});
  final String message;
  final bool unauthorized;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
    : http =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      storage = storage ?? const FlutterSecureStorage();
  final Dio http;
  final FlutterSecureStorage storage;
  String origin = defaultApiBase;
  String? token, refreshToken;
  Json? cachedProfile;
  Future<bool>? _refreshing;
  int _generation = 0;
  void Function()? onTokenChanged;

  Future<void> restore() async {
    final raw = await storage.read(key: 'session');
    if (raw != null) {
      final data = jsonDecode(raw) as Json;
      token = data['access_token'] as String?;
      refreshToken = data['refresh_token'] as String?;
      cachedProfile = data['profile'] as Json?;
    } else {
      token = await storage.read(key: 'token');
    }
  }

  Future<void> _persist() => storage.write(
    key: 'session',
    value: jsonEncode({
      'access_token': token,
      'refresh_token': refreshToken,
      'profile': cachedProfile,
    }),
  );
  Future<void> setSession(Json data) async {
    _generation++;
    token = data['access_token'] as String;
    refreshToken = data['refresh_token'] as String? ?? refreshToken;
    await _persist();
    await storage.delete(key: 'token');
  }

  Future<void> setToken(String value) async {
    token = value;
    await _persist();
  }

  Future<void> saveProfile(Json profile) async {
    cachedProfile = profile;
    await _persist();
  }

  Future<void> clearToken() async {
    _generation++;
    token = null;
    refreshToken = null;
    cachedProfile = null;
    await storage.delete(key: 'session');
    await storage.delete(key: 'token');
  }

  Future<void> signOut() async {
    final old = refreshToken;
    await clearToken();
    if (old != null) {
      unawaited(
        http
            .post<dynamic>(
              '$origin/api/v1/mobile/auth/logout',
              data: {'refresh_token': old},
              options: Options(receiveTimeout: const Duration(seconds: 4)),
            )
            .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
  }

  bool get _expiring {
    if (token == null) return true;
    try {
      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(token!.split('.')[1])),
        ),
      ) as Json;
      return (payload['exp'] as num).toInt() <=
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureSession({bool forceRefresh = false}) async {
    if (refreshToken != null && (forceRefresh || _expiring)) {
      await refreshSession();
    }
  }

  Future<bool> refreshSession() {
    if (_refreshing != null) return _refreshing!;
    final task = _refreshAccess();
    _refreshing = task;
    return task.whenComplete(() {
      if (identical(_refreshing, task)) _refreshing = null;
    });
  }

  Future<bool> _refreshAccess() async {
    final credential = refreshToken, generation = _generation;
    if (credential == null) return false;
    try {
      final response = await http.post<dynamic>(
        '$origin/api/v1/mobile/auth/refresh',
        data: {'refresh_token': credential},
      );
      if (generation != _generation || credential != refreshToken) return false;
      token = (response.data as Json)['access_token'] as String;
      await _persist();
      onTokenChanged?.call();
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ApiFailure('登录已失效，请重新登录', unauthorized: true);
      }
      throw const ApiFailure('连接失败，请稍后重试');
    }
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    dynamic data,
    Json? query,
    bool retried = false,
  }) async {
    if (!retried && !path.startsWith('/api/v1/mobile/auth/') && token != null) {
      await ensureSession();
    }
    final usedToken = token;
    try {
      final response = await http.request<dynamic>(
        '$origin$path',
        data: data is FormData ? data.clone() : data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
      return response.data;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 &&
          !retried &&
          refreshToken != null &&
          !path.startsWith('/api/v1/mobile/auth/')) {
        if ((token != usedToken && token != null) || await refreshSession()) {
          return request(
            path,
            method: method,
            data: data,
            query: query,
            retried: true,
          );
        }
      }
      if (status == 401) {
        throw const ApiFailure('登录已失效，请重新登录', unauthorized: true);
      }
      final body = error.response?.data;
      final detail = body is Map ? body['detail'] : null;
      if (detail is String) throw ApiFailure(detail);
      if (detail is List) throw const ApiFailure('请检查输入内容的格式和长度');
      if (status == 404) throw const ApiFailure('服务接口不可用');
      if (status == 403) throw const ApiFailure('当前账号无权访问此内容');
      throw const ApiFailure('连接失败，请检查网络');
    }
  }

  WebSocketChannel socket(String path) => WebSocketChannel.connect(
    Uri.parse('$origin$path').replace(
      scheme: Uri.parse(origin).scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {'token': token ?? ''},
    ),
  );
  String? imageUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.parse(origin).resolve(value);
    return uri.scheme == 'https' ||
            (uri.scheme == 'http' && uri.host == Uri.parse(origin).host)
        ? uri.toString()
        : null;
  }
}

/// One connection per feed, bounded retry, no retry after token rejection.
class LiveFeed {
  LiveFeed(
    this.client,
    this.path,
    this.onMessage,
    this.onStatus,
    this.onUnauthorized,
  );
  final ApiClient client;
  final String path;
  final void Function(Json) onMessage;
  final void Function(String) onStatus;
  final void Function() onUnauthorized;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat, _retry;
  bool _active = false;
  int _generation = 0, _attempt = 0;
  void start() {
    if (_active) return;
    _active = true;
    _connect(++_generation);
  }

  Future<void> _connect(int generation) async {
    if (!_active || generation != _generation) return;
    onStatus('正在连接');
    try {
      final channel = client.socket(path);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 12));
      if (!_active || generation != _generation) {
        await channel.sink.close();
        return;
      }
      _attempt = 0;
      onStatus('实时连接');
      _heartbeat = Timer.periodic(
        const Duration(seconds: 20),
        (_) => channel.sink.add('ping'),
      );
      _subscription = channel.stream.listen(
        (event) {
          if (!_active || generation != _generation || event == 'pong') return;
          try {
            final message = jsonDecode(event as String);
            if (message is Json) onMessage(message);
          } catch (_) {
            /* Ignore non-protocol frames. */
          }
        },
        onError: (_) => _disconnected(generation),
        onDone: () {
          if (channel.closeCode == 1008 &&
              _active &&
              generation == _generation) {
            stop();
            onUnauthorized();
          } else {
            _disconnected(generation);
          }
        },
      );
    } catch (_) {
      _disconnected(generation);
    }
  }

  void _disconnected(int generation) {
    if (!_active || generation != _generation || _retry != null) return;
    _heartbeat?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    onStatus('连接中断 · 自动重试');
    final seconds = min(30, 1 << min(_attempt++, 5));
    _retry = Timer(Duration(seconds: seconds), () {
      _retry = null;
      _connect(generation);
    });
  }

  void stop() {
    _active = false;
    _generation++;
    _retry?.cancel();
    _retry = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}
