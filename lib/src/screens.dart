import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'motion.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController(), _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _register = false, _obscure = true;
  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      ref
          .read(appProvider.notifier)
          .authenticate(_name.text.trim(), _password.text, register: _register);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const BrandMark(), const Spacer()]),
                    const SizedBox(height: 40),
                    AnimatedMetric(
                      _register ? '注册' : '登录',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _name,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? '请输入用户名' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) {
                        if (!state.busy) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: '显示或隐藏密码',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v?.isEmpty ?? true) ? '请输入密码' : null,
                    ),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ErrorNotice(state.error!),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: PressFeedback(
                        enabled: !state.busy,
                        child: FilledButton(
                          onPressed: state.busy ? null : _submit,
                          child: state.busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_register ? '注册' : '登录'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: state.busy
                            ? null
                            : ref.read(appProvider.notifier).microsoftLogin,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 52),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.window_rounded, size: 19),
                        label: const Text(
                          'Microsoft / Minecraft 登录',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: state.busy
                            ? null
                            : () => setState(() => _register = !_register),
                        child: Text(_register ? '已有账号？去登录' : '还没有账号？注册'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: TextButton(
                        onPressed: state.busy
                            ? null
                            : ref.read(appProvider.notifier).enterDemo,
                        child: const Text(
                          '演示模式',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CommunityShell extends ConsumerStatefulWidget {
  const CommunityShell({super.key});
  @override
  ConsumerState<CommunityShell> createState() => _CommunityShellState();
}

class _CommunityShellState extends ConsumerState<CommunityShell>
    with WidgetsBindingObserver {
  int _tab = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => ref
      .read(appProvider.notifier)
      .setForeground(state == AppLifecycleState.resumed);
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 20, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: BrandMark(),
                        ),
                      ),
                      if (state.demo)
                        const BadgePill('演示数据', color: AppColors.yellow),
                      const SizedBox(width: 10),
                      CircleAction(
                        icon: Icons.refresh_rounded,
                        label: '刷新',
                        onTap: state.refreshing
                            ? null
                            : () => ref.read(appProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: MotionPageDeck(
                    index: _tab,
                    children: const [
                      CommunityScreen(),
                      ServersScreen(),
                      ChatScreen(),
                      ProfileScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: FloatingDock(
        index: _tab,
        onChanged: (i) {
          if (i != _tab) setState(() => _tab = i);
        },
      ),
    );
  }
}

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  bool _allPlayers = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider), community = state.community;
    final mc = community?.mc ?? {};
    final available = community?.mcSource.available ?? false;
    final players = _allPlayers
        ? (community?.allPlayers ?? [])
        : (community?.humanPlayers ?? []);
    return RefreshIndicator(
      onRefresh: ref.read(appProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 104),
        children: [
          Text('服务器状态', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            community == null
                ? '正在加载…'
                : '${DateFormat('MM.dd · EEE').format(community.fetchedAt.toLocal())}   /   ${DateFormat('HH:mm:ss').format(community.fetchedAt.toLocal())} 更新',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 30),
          const SectionTitle('Minecraft'),
          if (state.communityError != null)
            ErrorNotice(
              '${state.communityError!}${community != null ? ' · 下方为上次数据' : ''}',
            ),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.public_rounded,
                      color: AppColors.green,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Deeraft',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    BadgePill(
                      !available
                          ? '状态未知'
                          : mc['online'] == true
                          ? '在线'
                          : '离线',
                      color: !available
                          ? AppColors.yellow
                          : mc['online'] == true
                          ? AppColors.green
                          : AppColors.coral,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedMetric(
                      available ? '${mc['online_count'] ?? 0}' : '—',
                      style: const TextStyle(
                        fontSize: 48,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 10, bottom: 5),
                      child: Text(
                        '在线',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    if (available)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: BadgePill(
                          '${(mc['latency_ms'] as num?)?.round() ?? '—'} ms',
                          color: AppColors.green,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  available
                      ? cleanMotd(mc['motd']?.toString() ?? '')
                      : (community?.mcSource.error ?? '等待服务器状态'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const Divider(),
                Row(
                  children: [
                    const Icon(
                      Icons.extension_outlined,
                      color: AppColors.muted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mc['version']?.toString() ?? 'Java Edition',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const Text(
                      'DEERAFT',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Text(
                      '在线玩家',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    SegmentedToggle(
                      labels: const ['真人', '全部'],
                      selected: _allPlayers ? 1 : 0,
                      onChanged: (i) => setState(() => _allPlayers = i == 1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MinecraftPlayers(
                  key: ValueKey(_allPlayers),
                  players: players,
                  available: available,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionTitle('KOOK'),
          if (community == null || !community.kookSource.available)
            SurfaceCard(
              child: EmptyContent(
                icon: Icons.headset_off_outlined,
                text: community?.kookSource.error ?? '正在获取语音状态',
              ),
            )
          else if (community.channels.isEmpty)
            const SurfaceCard(
              child: EmptyContent(icon: Icons.headset_outlined, text: '暂无语音频道'),
            )
          else
            ...community.channels.map((channel) {
              final users = List<Json>.from(channel['users'] as List? ?? []);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.volume_up_outlined,
                            color: users.isEmpty
                                ? AppColors.muted
                                : AppColors.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              channel['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${users.length}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (users.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            '暂无成员',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: users
                                .map(
                                  (u) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PlayerAvatar(
                                        u['name']?.toString() ?? '?',
                                        size: 26,
                                        color: AppColors.purple,
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 150,
                                        ),
                                        child: Text(
                                          u['name']?.toString() ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider), api = ref.read(apiProvider);
    return RefreshIndicator(
      onRefresh: ref.read(appProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 104),
        children: [
          Text('服务器列表', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 28),
          if (state.serversError != null) ErrorNotice(state.serversError!),
          if (state.servers.isEmpty && state.serversError == null)
            const SurfaceCard(
              child: EmptyContent(icon: Icons.dns_outlined, text: '暂无托管服务器'),
            ),
          ...state.servers.asMap().entries.map((entry) {
            final server = entry.value,
                running =
                    state.hostedStatus['is_running'] == true &&
                    state.hostedStatus['server_name'] == server['name'];
            final known = state.hostedStatus.containsKey('is_running');
            final accent = [
              AppColors.green,
              AppColors.purple,
              AppColors.yellow,
            ][entry.key % 3];
            final cover = api.imageUrl(server['img']?.toString());
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: PressFeedback(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surface,
                    useSafeArea: true,
                    sheetAnimationStyle: AnimationStyle(
                      duration: AppMotion.duration(context, AppMotion.standard),
                      reverseDuration: AppMotion.duration(
                        context,
                        AppMotion.fast,
                      ),
                    ),
                    builder: (_) => ServerDetails(
                      server: server,
                      running: running,
                      known: known,
                      players: state.hostedPlayers,
                    ),
                  ),
                  child: SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 142,
                          width: double.infinity,
                          child: cover == null
                              ? WorldArtwork(accent: accent, index: entry.key)
                              : Image.network(
                                  cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => WorldArtwork(
                                    accent: accent,
                                    index: entry.key,
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      server['name']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  BadgePill(
                                    !known
                                        ? '未知'
                                        : running
                                        ? '运行中'
                                        : '已停止',
                                    color: !known
                                        ? AppColors.yellow
                                        : running
                                        ? AppColors.green
                                        : AppColors.muted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                cleanMotd(server['motd']?.toString() ?? ''),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Text(
                                    'JAVA ${server['version']}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: AppColors.muted,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ServerDetails extends StatelessWidget {
  const ServerDetails({
    super.key,
    required this.server,
    required this.running,
    required this.known,
    required this.players,
  });
  final Json server;
  final bool running, known;
  final List<String> players;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  server['name']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BadgePill(
            !known
                ? '等待运行状态'
                : running
                ? '正在运行'
                : '已停止',
            color: running ? AppColors.green : AppColors.muted,
          ),
          const SizedBox(height: 20),
          Text(cleanMotd(server['motd']?.toString() ?? '')),
          const SizedBox(height: 12),
          Text(
            '版本 ${server['version']}',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (running) ...[
            const Divider(),
            Text(
              '在线玩家 · ${players.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Text(
                  players.isEmpty ? '暂无在线玩家' : players.join('、'),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            '服务器管理操作请使用网站。',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('聊天消息', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              if (state.chatError != null) ErrorNotice(state.chatError!),
            ],
          ),
        ),
        Expanded(
          child: state.chat.isEmpty
              ? const Center(
                  child: EmptyContent(
                    icon: Icons.forum_outlined,
                    text: '暂无聊天消息',
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 108),
                  itemCount: state.chat.length,
                  itemBuilder: (context, index) {
                    final msg = state.chat[state.chat.length - 1 - index];
                    if (msg.type == 'join' || msg.type == 'leave') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            '${msg.player} ${msg.type == 'join' ? '加入了游戏' : '离开了游戏'}  ·  ${msg.time}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      );
                    }
                    return MotionReveal(
                      key: ValueKey(msg.id ?? identityHashCode(msg)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlayerAvatar(msg.player, size: 34, minecraft: true),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          msg.player,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.green,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        msg.time,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: SelectableText(
                                      msg.message,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider), user = state.user!;
    final total = state.playtime.fold<num>(
      0,
      (sum, row) => sum + (row['playtime_minutes'] as num? ?? 0),
    );
    final rankedPlaytime = topPlaytime(state.playtime);
    final avatar = ref.read(apiProvider).imageUrl(user.avatarUrl);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 104),
      children: [
        Text('个人资料', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 28),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () async {
                      try {
                        await ref.read(appProvider.notifier).uploadAvatar();
                      } catch (e) {
                        if (context.mounted) showMessage(context, e.toString());
                      }
                    },
                    child: avatar == null
                        ? PlayerAvatar(user.username, size: 64)
                        : ClipOval(
                            child: Image.network(
                              avatar,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  PlayerAvatar(user.username, size: 64),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        BadgePill(
                          user.role == 'admin' ? '社区管理员' : 'Deeraft 成员',
                          color: AppColors.purple,
                        ),
                      ],
                    ),
                  ),
                  CircleAction(
                    icon: Icons.edit_outlined,
                    label: '编辑资料',
                    onTap: () => showEditProfile(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                user.bio.isEmpty ? '还没有留下签名。' : user.bio,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionTitle('游玩时长统计'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '累计游玩',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Text(
                durationLabel(total),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              if (state.playtimeError != null)
                ErrorNotice(state.playtimeError!),
              const Divider(),
              if (state.playtime.isEmpty)
                const Text(
                  '还没有存档游玩记录',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ...rankedPlaytime.map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p['server_name']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        durationLabel(p['playtime_minutes'] as num? ?? 0),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SectionTitle(
          '每日在线',
          action: TextButton(
            onPressed: () async {
              final day = await showDatePicker(
                context: context,
                initialDate: state.dailyDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (day != null) ref.read(appProvider.notifier).loadDaily(day);
            },
            child: Text(
              DateFormat('MM.dd').format(state.dailyDate),
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ),
        SurfaceCard(
          child: Column(
            children: [
              if (state.dailyError != null) ErrorNotice(state.dailyError!),
              if (state.daily.isEmpty)
                const EmptyContent(
                  icon: Icons.schedule_rounded,
                  text: '这一天还没有在线记录',
                ),
              ...state.daily.map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      PlayerAvatar(
                        p['player']?.toString() ?? '?',
                        size: 30,
                        minecraft: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p['player']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        durationLabel(p['playtime_minutes'] as num? ?? 0),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.yellow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: () => ref.read(appProvider.notifier).logout(),
          child: Text(state.demo ? '退出演示' : '退出登录'),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'DEERAFT  ·  v0.3.1',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<void> showEditProfile(BuildContext context, WidgetRef ref) async {
  final user = ref.read(appProvider).user!,
      name = TextEditingController(),
      bio = TextEditingController();
  name.text = user.username;
  bio.text = user.bio;
  bool saving = false;
  String? error;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('编辑个人资料', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                TextField(
                  controller: name,
                  maxLength: 32,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: bio,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '个人签名'),
                ),
                if (error != null) ErrorNotice(error!),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (name.text.trim().length < 2 ||
                                RegExp(r'\s').hasMatch(name.text.trim())) {
                              setLocal(() => error = '用户名需为 2–32 位且不含空白');
                              return;
                            }
                            setLocal(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              await ref
                                  .read(appProvider.notifier)
                                  .updateProfile(
                                    name.text.trim(),
                                    bio.text.trim(),
                                  );
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                setLocal(() {
                                  saving = false;
                                  error = e.toString();
                                });
                              }
                            }
                          },
                    child: Text(saving ? '保存中…' : '保存修改'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => MotionReveal(
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedSize(
        duration: AppMotion.duration(context, AppMotion.standard),
        curve: AppMotion.curve,
        alignment: Alignment.topCenter,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.forest_outlined, size: 23, color: Colors.white),
      SizedBox(width: 8),
      Text(
        'deeraft',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
        ),
      ),
    ],
  );
}

class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => PressFeedback(
    enabled: onTap != null,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: onTap == null && icon == Icons.refresh_rounded
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            )
          : Icon(icon, size: 21),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.raised,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(42, 42),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.action});
  final String title;
  final String? trailing;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ?action,
      ],
    ),
  );
}

class BadgePill extends StatelessWidget {
  const BadgePill(this.text, {super.key, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.duration(context, AppMotion.fast),
    curve: AppMotion.curve,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
    ),
  );
}

class EmptyContent extends StatelessWidget {
  const EmptyContent({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.coral,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.coral, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar(
    this.name, {
    super.key,
    this.size = 36,
    this.color,
    this.minecraft = false,
  });
  final String name;
  final double size;
  final Color? color;
  final bool minecraft;
  @override
  Widget build(BuildContext context) {
    if (minecraft) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.network(
          'https://minotar.net/avatar/${Uri.encodeComponent(name)}/64',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: AppColors.raised,
            child: Icon(
              Icons.person_outline_rounded,
              size: size * .6,
              color: AppColors.muted,
            ),
          ),
        ),
      );
    }
    final accent =
        color ??
        [
          AppColors.green,
          AppColors.purple,
          AppColors.yellow,
          AppColors.coral,
        ][name.codeUnits.fold<int>(0, (a, b) => a + b) % 4];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontSize: size * .38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class MinecraftPlayers extends StatefulWidget {
  const MinecraftPlayers({
    super.key,
    required this.players,
    required this.available,
  });
  final List<String> players;
  final bool available;
  @override
  State<MinecraftPlayers> createState() => _MinecraftPlayersState();
}

class _MinecraftPlayersState extends State<MinecraftPlayers> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    if (widget.players.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: EmptyContent(
          icon: Icons.people_outline_rounded,
          text: widget.available ? '暂无在线玩家' : '玩家列表暂不可用',
        ),
      );
    }
    final visible = expanded ? widget.players : widget.players.take(8).toList();
    return Column(
      children: [
        AnimatedSize(
          duration: AppMotion.duration(context, AppMotion.standard),
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 260 ? 3 : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 16,
                children: visible
                    .map(
                      (name) => SizedBox(
                        width: width,
                        child: Tooltip(
                          message: name,
                          child: Column(
                            children: [
                              PlayerAvatar(name, size: 36, minecraft: true),
                              const SizedBox(height: 7),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        if (widget.players.length > 8)
          TextButton(
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(
              expanded ? '收起' : '展开（${widget.players.length}）',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        labels.length,
        (i) => PressFeedback(
          child: InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.curve,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected == i ? AppColors.raised : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.duration(context, AppMotion.fast),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'DMSans',
                  fontFamilyFallback: const ['NotoSansSC'],
                  color: selected == i ? Colors.white : AppColors.muted,
                ),
                child: Text(labels[i]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class WorldArtwork extends StatelessWidget {
  const WorldArtwork({super.key, required this.accent, required this.index});
  final Color accent;
  final int index;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _WorldPainter(accent, index),
    child: const SizedBox.expand(),
  );
}

class _WorldPainter extends CustomPainter {
  _WorldPainter(this.accent, this.index);
  final Color accent;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: .14), const Color(0xFF181C1C)],
        ).createShader(Offset.zero & size),
    );
    final unit = size.width / 18;
    for (var x = 0; x < 19; x++) {
      final height = [
        2,
        3,
        3,
        4,
        5,
        4,
        3,
        4,
        6,
        5,
        4,
        3,
        4,
        4,
        5,
        6,
        5,
        4,
        3,
      ][(x + index * 3) % 19];
      for (var y = 0; y < height; y++) {
        canvas.drawRect(
          Rect.fromLTWH(
            x * unit,
            size.height - (y + 1) * unit,
            unit - 1,
            unit - 1,
          ),
          Paint()..color = accent.withValues(alpha: .06 + y * .022),
        );
      }
    }
    canvas.drawCircle(
      Offset(size.width * .8, size.height * .28),
      13,
      Paint()..color = accent.withValues(alpha: .22),
    );
  }

  @override
  bool shouldRepaint(_WorldPainter old) =>
      old.accent != accent || old.index != index;
}
