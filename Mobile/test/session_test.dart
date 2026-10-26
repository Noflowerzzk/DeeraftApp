import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deeraft/src/api.dart';

String jwt(int expiry) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': expiry}))).replaceAll('=', '')}.test';
ResponseBody body(Object data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    'content-type': ['application/json'],
  },
);

class Adapter implements HttpClientAdapter {
  Adapter(this.handle);
  final Future<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'parallel expired requests renew once and persist across App restart',
    () async {
      var refreshes = 0;
      final fresh = jwt(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400);
      final dio = Dio()
        ..httpClientAdapter = Adapter((request) async {
          if (request.path.endsWith('/refresh')) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return body({'access_token': fresh});
          }
          return request.headers['Authorization'] == 'Bearer $fresh'
              ? body({'ok': true})
              : body({}, 401);
        });
      final api = ApiClient(dio: dio);
      await api.setSession({
        'access_token': jwt(0),
        'refresh_token': 'refresh-credential',
      });
      await Future.wait(
        List.generate(8, (_) => api.request('/api/v1/auth/me')),
      );
      expect(refreshes, 1);
      final restarted = ApiClient();
      await restarted.restore();
      expect(restarted.token, fresh);
      expect(restarted.refreshToken, 'refresh-credential');
    },
  );
  test(
    '401 on an unexpired token renews and retries original request',
    () async {
      var calls = 0, refreshes = 0;
      final api = ApiClient(
        dio: Dio()
          ..httpClientAdapter = Adapter((request) async {
            if (request.path.endsWith('/refresh')) {
              refreshes++;
              return body({'access_token': 'new-token'});
            }
            calls++;
            return calls == 1 ? body({}, 401) : body({'ok': true});
          }),
      );
      await api.setSession({
        'access_token': jwt(9999999999),
        'refresh_token': 'refresh-credential',
      });
      expect(await api.request('/api/v1/servers'), {'ok': true});
      expect(calls, 2);
      expect(refreshes, 1);
    },
  );
  test('network failure during renewal keeps persistent login', () async {
    final api = ApiClient(
      dio: Dio()
        ..httpClientAdapter = Adapter(
          (r) async => throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          ),
        ),
    );
    await api.setSession({
      'access_token': jwt(0),
      'refresh_token': 'refresh-credential',
    });
    await expectLater(
      api.ensureSession(),
      throwsA(
        isA<ApiFailure>().having((e) => e.unauthorized, 'unauthorized', false),
      ),
    );
    final restarted = ApiClient();
    await restarted.restore();
    expect(restarted.refreshToken, 'refresh-credential');
  });
  test('logout during in-flight renewal cannot restore the session', () async {
    final pending = Completer<ResponseBody>();
    final api = ApiClient(
      dio: Dio()..httpClientAdapter = Adapter((r) => pending.future),
    );
    await api.setSession({
      'access_token': jwt(0),
      'refresh_token': 'refresh-credential',
    });
    final task = api.refreshSession();
    await Future<void>.delayed(Duration.zero);
    await api.clearToken();
    pending.complete(body({'access_token': 'stale-token'}));
    expect(await task, false);
    final restarted = ApiClient();
    await restarted.restore();
    expect(restarted.token, isNull);
    expect(restarted.refreshToken, isNull);
  });
}
