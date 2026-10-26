import 'package:flutter_test/flutter_test.dart';
import 'package:deeraft/src/api.dart';
import 'package:deeraft/src/models.dart';

void main() {
  test('durable chat IDs preserve identical messages from distinct events', () {
    final one = ChatMessage.fromJson({
      'id': 1,
      'time': '12:00:00',
      'player': 'A',
      'message': 'hello',
    });
    final two = ChatMessage.fromJson({
      'id': 2,
      'time': '12:00:00',
      'player': 'A',
      'message': 'hello',
    });
    expect(mergeChat([one], [two]).length, 2);
    expect(mergeChat([one], [one, two]).length, 2);
  });
  test('playtime ranking selects top five without changing totals source', () {
    final rows = List.generate(
      8,
      (i) => <String, dynamic>{
        'server_name': 'server-$i',
        'playtime_minutes': i * 10,
      },
    );
    final ranked = topPlaytime(rows);
    expect(ranked.map((r) => r['playtime_minutes']), [70, 60, 50, 40, 30]);
    expect(rows.first['playtime_minutes'], 0);
    expect(rows.length, 8);
  });
  test(
    'history/live overlap does not duplicate, genuine repeated messages remain',
    () {
      const a = ChatMessage(time: '10:00:00', player: 'a', message: 'hello');
      const b = ChatMessage(time: '10:00:01', player: 'b', message: 'hi');
      expect(mergeChat([a, b], [b, a]).map((m) => m.player), ['a', 'b', 'a']);
      expect(mergeChat([], [a, a]).length, 2);
      expect(mergeChat([a], [b], snapshot: true), [b]);
    },
  );
  test('bounded chat history and formatting', () {
    final list = List.generate(
      400,
      (i) => ChatMessage(time: '$i', player: 'a', message: '$i'),
    );
    expect(mergeChat([], list).length, 300);
    expect(cleanMotd('§aHello §l世界'), 'Hello 世界');
    expect(durationLabel(90), '1.5 小时');
  });
  test('origin validation rejects cleartext and credential-bearing URLs', () {
    expect(normalizeOrigin(' https://example.com/ '), 'https://example.com');
    expect(
      normalizeOrigin('http://mc.ainfinitythecoder.cn/'),
      'http://mc.ainfinitythecoder.cn',
    );
    for (final value in [
      'http://example.com',
      'https://a:b@example.com',
      'https://example.com/api',
      'https://example.com?token=x',
      'not a url',
    ]) {
      expect(() => normalizeOrigin(value), throwsFormatException);
    }
  });
  test('RFC 7636 S256 challenge', () {
    expect(
      pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });
  test('partial source failure is not treated as no players online', () {
    final result = CommunityStatus.fromJson({
      'mc': null,
      'kook': {'channels': []},
      'sources': {
        'mc': {'available': false, 'error': 'timeout'},
        'kook': {'available': true},
      },
    });
    expect(result.mcSource.available, false);
    expect(result.mcSource.error, 'timeout');
    expect(result.kookSource.available, true);
    expect(result.humanPlayers, isEmpty);
  });
}
