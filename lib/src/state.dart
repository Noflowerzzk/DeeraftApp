import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'demo.dart';
import 'models.dart';

class AppState {
  bool booting = true, busy = false, refreshing = false, demo = false;
  UserProfile? user;
  CommunityStatus? community;
  List<Json> servers = [], playtime = [], daily = [];
  List<String> hostedPlayers = [];
  List<ChatMessage> chat = [];
  Json hostedStatus = {};
  DateTime dailyDate = DateTime.now();
  String? error,
      communityError,
      serversError,
      playtimeError,
      dailyError,
      chatError;
  String chatConnection = '尚未连接';
  AppState clone() => AppState()
    ..booting = booting
    ..busy = busy
    ..refreshing = refreshing
    ..demo = demo
    ..user = user
    ..community = community
    ..servers = servers
    ..playtime = playtime
    ..daily = daily
    ..hostedPlayers = hostedPlayers
    ..chat = chat
    ..hostedStatus = hostedStatus
    ..dailyDate = dailyDate
    ..error = error
    ..communityError = communityError
    ..serversError = serversError
    ..playtimeError = playtimeError
    ..dailyError = dailyError
    ..chatError = chatError
    ..chatConnection = chatConnection;
}

final apiProvider = Provider<ApiClient>((ref) => ApiClient());
final appProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  late ApiClient api;
  final List<LiveFeed> _feeds = [];
  Timer? _poll;
  StreamSubscription<Uri>? _links;
  bool _disposed = false, _foreground = true;
  bool _startingLive = false, _recovering = false;
  int _session = 0;
  AppLinks? _appLinks;
  @override
  AppState build() {
    api = ref.read(apiProvider);
    api.onTokenChanged = () {
      if (!_disposed && state.user != null) {
        _stopLive();
        _startLive();
      }
    };
    ref.onDispose(() {
      _disposed = true;
      _stopLive();
      _links?.cancel();
      api.onTokenChanged = null;
    });
    Future.microtask(_bootstrap);
    return AppState();
  }

  void _emit(void Function(AppState) change) {
    if (_disposed) return;
    final next = state.clone();
    change(next);
    state = next;
  }

  Future<void> _bootstrap() async {
    if (demoBuild) {
      enterDemo();
      return;
    }
    try {
      await api.restore();
      _appLinks = AppLinks();
      _links = _appLinks!.uriLinkStream.listen(_handleLink, onError: (_) {});
      if (api.token != null) {
        if (api.refreshToken == null) {
          await api.setSession(
            await api.request('/api/v1/mobile/auth/session', method: 'POST')
                as Json,
          );
        }
        await api.ensureSession();
        final profile = await api.request('/api/v1/auth/me') as Json;
        final user = UserProfile.fromJson(profile);
        await api.saveProfile(profile);
        _emit((s) => s.user = user);
        unawaited(refresh());
        _startLive();
      }
    } catch (e) {
      if (e is ApiFailure && e.unauthorized) {
        await api.clearToken();
        _emit((s) => s.error = e.toString());
      } else if (api.cachedProfile != null) {
        _emit((s) {
          s.user = UserProfile.fromJson(api.cachedProfile!);
          s.communityError = e.toString();
        });
        _startLive();
      } else {
        _emit((s) => s.error = e.toString());
      }
    } finally {
      _emit((s) => s.booting = false);
    }
  }

  void enterDemo() {
    _session++;
    _stopLive();
    _emit((s) {
      s.booting = false;
      s.demo = true;
      s.error = null;
      s.user = const UserProfile(
        username: 'Noflowerzzk',
        bio: '在方块世界里，和朋友一起慢慢探索。',
      );
      s.community = CommunityStatus.fromJson(demoCommunity());
      s.servers = demoServers;
      s.chat = demoChat;
      s.hostedStatus = {'is_running': true, 'server_name': 'SSCG26.3'};
      s.hostedPlayers = ['Noflowerzzk', 'brydim'];
      s.playtime = [
        {'server_name': 'SSCG26.3', 'playtime_minutes': 2568},
        {'server_name': 'BlockRacing_New', 'playtime_minutes': 744},
      ];
      s.daily = [
        {'player': 'Noflowerzzk', 'playtime_minutes': 124},
        {'player': 'AInfinity_Dream', 'playtime_minutes': 96},
      ];
      s.chatConnection = '演示数据';
    });
  }

  Future<void> authenticate(
    String username,
    String password, {
    bool register = false,
  }) async {
    _emit((s) {
      s.busy = true;
      s.error = null;
    });
    try {
      if (register) {
        await api.request(
          '/api/v1/auth/register',
          method: 'POST',
          data: {'username': username, 'password': password},
        );
      }
      final data = await api.request(
        '/api/v1/mobile/auth/login',
        method: 'POST',
        data: {'username': username, 'password': password},
      ) as Json;
      await _acceptSession(data);
    } catch (e) {
      _emit((s) => s.error = e.toString());
    } finally {
      _emit((s) => s.busy = false);
    }
  }

  Future<void> _acceptSession(Json data) async {
    _session++;
    await api.setSession(data);
    final profile = await api.request('/api/v1/auth/me') as Json;
    final user = UserProfile.fromJson(profile);
    await api.saveProfile(profile);
    _emit((s) {
      s.user = user;
      s.demo = false;
      s.error = null;
    });
    unawaited(refresh());
    _startLive();
  }

  Future<void> logout({String? reason}) async {
    _session++;
    _stopLive();
    try {
      await api.signOut();
      await api.storage.delete(key: 'oauth_pending');
    } catch (_) {
      /* UI still logs out if storage unavailable. */
    }
    if (!_disposed) {
      state = AppState()
        ..booting = false
        ..error = reason;
    }
  }

  Future<void> _failure(
    Object error,
    void Function(AppState, String) setError,
  ) async {
    if (error is ApiFailure && error.unauthorized) {
      await logout(reason: error.message);
      return;
    }
    _emit((s) => setError(s, error.toString()));
  }

  Future<void> refresh() async {
    if (state.user == null || state.refreshing) return;
    if (state.demo) {
      _emit((s) => s.community = CommunityStatus.fromJson(demoCommunity()));
      return;
    }
    final session = _session;
    _emit((s) => s.refreshing = true);
    await Future.wait([
      _load(
        '/api/v1/community/status',
        (s, data) {
          s.community = CommunityStatus.fromJson(data as Json);
          s.communityError = null;
        },
        (s, e) => s.communityError = e,
        session,
      ),
      _load(
        '/api/v1/servers',
        (s, data) {
          s.servers = List<Json>.from(data as List);
          s.serversError = null;
        },
        (s, e) => s.serversError = e,
        session,
      ),
      loadPlaytime(),
      loadDaily(state.dailyDate),
    ]);
    if (session == _session) _emit((s) => s.refreshing = false);
  }

  Future<void> _load(
    String path,
    void Function(AppState, dynamic) apply,
    void Function(AppState, String) failed,
    int session, {
    Json? query,
  }) async {
    try {
      final data = await api.request(path, query: query);
      if (session == _session) _emit((s) => apply(s, data));
    } catch (e) {
      if (session == _session) await _failure(e, failed);
    }
  }

  Future<void> loadPlaytime() async {
    if (state.demo || state.user == null) return;
    await _load(
      '/api/v1/servers/player/me/playtime',
      (s, d) {
        s.playtime = List<Json>.from(d as List);
        s.playtimeError = null;
      },
      (s, e) => s.playtimeError = e,
      _session,
    );
  }

  Future<void> loadDaily(DateTime day) async {
    _emit((s) => s.dailyDate = day);
    if (state.demo || state.user == null) return;
    final date = day.toIso8601String().substring(0, 10);
    final session = _session;
    try {
      final d = await api.request(
        '/api/v1/mobile/daily-playtime',
        query: {'date': date},
      ) as Json;
      if (session == _session &&
          state.dailyDate.toIso8601String().startsWith(date)) {
        _emit((s) {
          s.daily = List<Json>.from(d['players'] as List);
          s.dailyError = null;
        });
      }
    } catch (e) {
      if (session == _session) await _failure(e, (s, e) => s.dailyError = e);
    }
  }

  void setForeground(bool active) {
    _foreground = active;
    if (active && state.user != null) {
      unawaited(refresh());
      _startLive();
    } else {
      _stopLive();
    }
  }

  Future<void> _startLive() async {
    if (_disposed ||
        _startingLive ||
        !_foreground ||
        state.demo ||
        state.user == null ||
        _feeds.isNotEmpty) {
      return;
    }
    _startingLive = true;
    final startingSession = _session;
    try {
      await api.ensureSession();
    } catch (e) {
      await _failure(e, (s, e) => s.communityError = e);
      return;
    } finally {
      _startingLive = false;
    }
    if (_disposed ||
        startingSession != _session ||
        !_foreground ||
        state.user == null ||
        _feeds.isNotEmpty) {
      return;
    }
    final session = _session;
    void unauthorized() {
      if (session == _session) unawaited(_recoverSession());
    }

    _feeds.addAll([
      LiveFeed(
        api,
        '/api/v1/servers/status/ws',
        (d) {
          if (session == _session) _emit((s) => s.hostedStatus = d);
        },
        (_) {},
        unauthorized,
      ),
      LiveFeed(
        api,
        '/api/v1/servers/online_players/ws',
        (d) {
          if (session == _session && d['players'] is List) {
            _emit(
              (s) => s.hostedPlayers = List<String>.from(d['players'] as List),
            );
          }
        },
        (_) {},
        unauthorized,
      ),
      LiveFeed(
        api,
        '/api/v1/mobile/chat/ws',
        (d) {
          if (session != _session) return;
          final incoming = List<Json>.from(d['messages'] as List? ?? [])
              .map(ChatMessage.fromJson)
              .toList();
          _emit((s) {
            s.chat = mergeChat(
              s.chat,
              incoming,
              snapshot: d['type'] == 'initial_chat_messages',
            );
            s.chatError = null;
          });
        },
        (status) {
          if (session == _session) _emit((s) => s.chatConnection = status);
        },
        unauthorized,
      ),
    ]);
    for (final feed in _feeds) {
      feed.start();
    }
    _poll = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshCommunity(session),
    );
  }

  Future<void> _recoverSession() async {
    if (_recovering) return;
    _recovering = true;
    try {
      if (!await api.refreshSession()) {
        await logout(reason: '请重新登录');
        return;
      }
      _stopLive();
      await _startLive();
    } catch (e) {
      await _failure(e, (s, e) => s.communityError = e);
    } finally {
      _recovering = false;
    }
  }

  Future<void> _refreshCommunity(int session) async {
    if (state.refreshing || session != _session) return;
    await _load(
      '/api/v1/community/status',
      (s, d) {
        s.community = CommunityStatus.fromJson(d as Json);
        s.communityError = null;
      },
      (s, e) => s.communityError = e,
      session,
    );
  }

  void _stopLive() {
    _poll?.cancel();
    _poll = null;
    for (final f in _feeds) {
      f.stop();
    }
    _feeds.clear();
  }

  Future<void> updateProfile(String username, String bio) async {
    if (state.demo) {
      _emit((s) => s.user = UserProfile(username: username, bio: bio));
      return;
    }
    if (username != state.user!.username) {
      final d = await api.request(
        '/api/v1/auth/me/username',
        method: 'PUT',
        data: {'username': username},
      ) as Json;
      await api.setToken(d['access_token'] as String);
      _emit((s) => s.user = UserProfile.fromJson(d['profile'] as Json));
      await api.saveProfile(d['profile'] as Json);
      _stopLive();
      _startLive();
    }
    final d = await api.request(
      '/api/v1/auth/me/bio',
      method: 'PUT',
      data: {'bio': bio},
    ) as Json;
    _emit((s) => s.user = UserProfile.fromJson(d));
    unawaited(loadPlaytime());
  }

  Future<void> uploadAvatar() async {
    if (state.demo) throw const ApiFailure('演示模式不上传文件');
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) throw const ApiFailure('头像不能超过 5 MB');
    final d = await api.request(
      '/api/v1/auth/me/avatar',
      method: 'POST',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      }),
    ) as Json;
    _emit((s) => s.user = UserProfile.fromJson(d));
  }

  Future<void> microsoftLogin() async {
    _emit((s) {
      s.busy = true;
      s.error = null;
    });
    try {
      final verifier = randomSecret(), clientState = randomSecret();
      await api.storage.write(
        key: 'oauth_pending',
        value:
            '$clientState|$verifier|${DateTime.now().millisecondsSinceEpoch}',
      );
      final d = await api.request(
        '/api/v1/mobile/auth/microsoft/start',
        method: 'POST',
        data: {
          'code_challenge': pkceChallenge(verifier),
          'client_state': clientState,
        },
      ) as Json;
      final uri = Uri.parse(d['authorize_url'] as String);
      if (uri.scheme != 'https' || uri.host != 'login.microsoftonline.com') {
        throw const ApiFailure('授权地址无效');
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const ApiFailure('无法打开系统浏览器');
      }
    } catch (e) {
      _emit((s) => s.error = e.toString());
    } finally {
      _emit((s) => s.busy = false);
    }
  }

  Future<void> _handleLink(Uri uri) async {
    if (uri.scheme != 'deeraft' ||
        uri.host != 'oauth' ||
        uri.path != '/callback') {
      return;
    }
    try {
      final pending = await api.storage.read(key: 'oauth_pending');
      if (pending == null) throw const ApiFailure('没有待完成的登录，请重新发起');
      final parts = pending.split('|');
      if (parts.length != 3 ||
          parts[0] != uri.queryParameters['state'] ||
          DateTime.now().millisecondsSinceEpoch - int.parse(parts[2]) >
              300000) {
        throw const ApiFailure('登录状态无效或已过期');
      }
      await api.storage.delete(key: 'oauth_pending');
      if (uri.queryParameters.containsKey('error')) {
        throw const ApiFailure('微软登录未完成，请重试');
      }
      final code = uri.queryParameters['code'];
      if (code == null) throw const ApiFailure('登录回调缺少交换码');
      final d = await api.request(
        '/api/v1/mobile/auth/microsoft/exchange',
        method: 'POST',
        data: {'code': code, 'code_verifier': parts[1]},
      ) as Json;
      await _acceptSession(d);
    } catch (e) {
      _emit((s) => s.error = e.toString());
    }
  }
}
