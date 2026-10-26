typedef Json = Map<String, dynamic>;

class UserProfile {
  const UserProfile({
    required this.username,
    this.bio = '',
    this.avatarUrl,
    this.role = 'user',
  });
  final String username, bio, role;
  final String? avatarUrl;
  factory UserProfile.fromJson(Json json) => UserProfile(
    username: json['username'] as String,
    bio: json['bio'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    role: json['role'] as String? ?? 'user',
  );
}

class SourceState {
  const SourceState({required this.available, this.error, this.updatedAt});
  final bool available;
  final String? error;
  final DateTime? updatedAt;
  factory SourceState.fromJson(Json json) => SourceState(
    available: json['available'] == true,
    error: json['error'] as String?,
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
  );
}

class CommunityStatus {
  const CommunityStatus({
    required this.mc,
    required this.kook,
    required this.mcSource,
    required this.kookSource,
    required this.fetchedAt,
  });
  final Json mc, kook;
  final SourceState mcSource, kookSource;
  final DateTime fetchedAt;
  factory CommunityStatus.fromJson(Json json) {
    final sources = json['sources'] as Json? ?? {};
    return CommunityStatus(
      mc: json['mc'] as Json? ?? {},
      kook: json['kook'] as Json? ?? {},
      mcSource: SourceState.fromJson(sources['mc'] as Json? ?? {}),
      kookSource: SourceState.fromJson(sources['kook'] as Json? ?? {}),
      fetchedAt:
          DateTime.tryParse(json['fetched_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
  List<String> get humanPlayers =>
      List<String>.from(mc['human_players'] as List? ?? []);
  List<String> get allPlayers =>
      List<String>.from(mc['players'] as List? ?? []);
  List<Json> get channels => List<Json>.from(kook['channels'] as List? ?? []);
}

class ChatMessage {
  const ChatMessage({
    required this.time,
    required this.player,
    required this.message,
    this.type = 'chat',
  });
  final String time, player, message, type;
  factory ChatMessage.fromJson(Json json) => ChatMessage(
    time: json['time']?.toString() ?? '',
    player: json['player']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    type: json['type']?.toString() ?? 'chat',
  );
  String get key => '$time\u0000$player\u0000$type\u0000$message';
}

List<ChatMessage> mergeChat(
  List<ChatMessage> previous,
  List<ChatMessage> incoming, {
  bool snapshot = false,
}) {
  if (snapshot) {
    return incoming.length > 300
        ? incoming.sublist(incoming.length - 300)
        : incoming;
  }
  var overlap = 0;
  for (var n = 1; n <= previous.length && n <= incoming.length; n++) {
    var matches = true;
    for (var i = 0; i < n; i++) {
      if (previous[previous.length - n + i].key != incoming[i].key) {
        matches = false;
        break;
      }
    }
    if (matches) overlap = n;
  }
  final result = [...previous, ...incoming.skip(overlap)];
  return result.length > 300 ? result.sublist(result.length - 300) : result;
}

String cleanMotd(String text) =>
    text.replaceAll(RegExp(r'§[0-9a-fk-or]', caseSensitive: false), '');
String durationLabel(num minutes) => minutes < 60
    ? '${minutes.round()} 分钟'
    : '${(minutes / 60).toStringAsFixed(1)} 小时';
