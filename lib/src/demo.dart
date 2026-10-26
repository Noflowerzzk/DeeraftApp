import 'models.dart';

Json demoCommunity() => {
  'fetched_at': DateTime.now().toUtc().toIso8601String(),
  'sources': {
    for (final source in ['mc', 'kook'])
      source: {
        'available': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
  },
  'mc': {
    'online': true,
    'motd': 'Deeraft',
    'version': 'Java 1.21.4',
    'latency_ms': 32,
    'online_count': 12,
    'max_players': 100,
    'human_players': [
      'AInfinity_Dream',
      'Noflowerzzk',
      'brydim',
      'LilacDreamMCPK',
      'Alnicoaaa',
      'PlumageW',
    ],
    'players': [
      'AInfinity_Dream',
      'Noflowerzzk',
      'brydim',
      'LilacDreamMCPK',
      'Alnicoaaa',
      'PlumageW',
      'Camera_01',
      'Camera_02',
      'Camera_03',
      'Camera_04',
      'Camera_05',
      'Camera_06',
    ],
  },
  'kook': {
    'name': 'Deeraft',
    'channels': [
      {
        'id': '1',
        'name': '一起玩 MC',
        'users': [
          {'id': '1', 'name': 'AInfinity'},
          {'id': '2', 'name': 'PlumageW'},
          {'id': '3', 'name': 'brydim'},
        ],
      },
      {
        'id': '2',
        'name': '随便聊聊',
        'users': [
          {'id': '4', 'name': 'Alnico'},
          {'id': '5', 'name': 'LilacDream'},
        ],
      },
      {'id': '3', 'name': '挂机小屋', 'users': []},
    ],
  },
};
const demoServers = <Json>[
  {'name': 'SSCG26.3', 'version': '1.21.4', 'motd': '生存服务器', 'img': ''},
  {'name': 'BlockRacing_New', 'version': '1.20.4', 'motd': '跑酷服务器', 'img': ''},
  {'name': 'Deeraft Creative', 'version': '1.21.4', 'motd': '创造服务器', 'img': ''},
];
const demoChat = [
  ChatMessage(
    time: '14:32:01',
    player: 'AInfinity_Dream',
    message: '',
    type: 'join',
  ),
  ChatMessage(
    time: '14:32:15',
    player: 'AInfinity_Dream',
    message: '有人一起去新地图吗？',
  ),
  ChatMessage(time: '14:33:02', player: 'Noflowerzzk', message: '来了！先让我整理一下背包'),
  ChatMessage(time: '14:33:18', player: 'brydim', message: '我在出生点等你们 🌲'),
  ChatMessage(time: '14:34:40', player: 'PlumageW', message: '今天的服务器好流畅'),
  ChatMessage(
    time: '14:35:10',
    player: 'LilacDreamMCPK',
    message: '',
    type: 'leave',
  ),
];
