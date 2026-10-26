import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'state.dart';
import 'motion.dart';
import 'community_scroll.dart';
import 'theme.dart';

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
    final state = ref.watch(appProvider), c = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: c.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.forest,
                            color: c.onPrimaryContainer,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Deeraft',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      AnimatedMetric(
                        _register ? '注册' : '登录',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _name,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? '请输入用户名' : null,
                      ),
                      const SizedBox(height: 20),
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
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: '显示或隐藏密码',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v?.isEmpty ?? true) ? '请输入密码' : null,
                      ),
                      if (state.error != null) ErrorNotice(state.error!),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: state.busy ? null : _submit,
                        child: state.busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_register ? '注册' : '登录'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: state.busy
                            ? null
                            : ref.read(appProvider.notifier).microsoftLogin,
                        icon: const Icon(Icons.window_outlined),
                        label: const Text('Microsoft / Minecraft 登录'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => setState(() => _register = !_register),
                        child: Text(_register ? '已有账号？去登录' : '还没有账号？注册'),
                      ),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : ref.read(appProvider.notifier).enterDemo,
                        child: const Text('演示模式'),
                      ),
                    ],
                  ),
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
  static const _titles = ['Deeraft', '服务器', '聊天消息', '个人资料'];
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
      appBar: AppBar(
        backgroundColor: _tab == 0 ? appDarkTheme.colorScheme.surface : null,
        foregroundColor: _tab == 0 ? appDarkTheme.colorScheme.onSurface : null,
        title: Text(_titles[_tab]),
        actions: [
          if (state.demo)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: BadgePill('演示数据'),
            ),
          CircleAction(
            icon: Icons.refresh,
            label: '刷新',
            onTap: state.refreshing
                ? null
                : () => ref.read(appProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
        ),
      ),
      bottomNavigationBar: FloatingDock(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
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
  final _scroll = ScrollController();
  bool _allPlayers = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider), community = state.community;
    final c = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final players = _allPlayers
        ? (community?.allPlayers ?? <String>[])
        : (community?.humanPlayers ?? <String>[]);
    final available = community?.mcSource.available ?? false;
    final sheetColor = c.brightness == Brightness.dark
        ? c.surfaceContainerLow
        : c.surface;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded =
            (constraints.maxHeight * .56).clamp(350.0, 400.0) +
            (scale - 1).clamp(0.0, 2.0) * 210;
        final collapsed = 92 * scale + CommunityStatusHeader.sheetRadius;
        return ColoredBox(
          color: appDarkTheme.colorScheme.surface,
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              overscroll: false,
            ),
            child: RefreshIndicator(
              color: appDarkTheme.colorScheme.primary,
              backgroundColor: appDarkTheme.colorScheme.surfaceContainerHigh,
              onRefresh: ref.read(appProvider.notifier).refresh,
              child: CustomScrollView(
                key: const PageStorageKey('community-scroll'),
                controller: _scroll,
                physics: CommunitySnapPhysics(
                  snapExtent: expanded - collapsed,
                  reduceMotion: reduce,
                  parent: reduce
                      ? const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        )
                      : const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                ),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: CommunityStatusHeader(
                      community: community,
                      expandedExtent: expanded,
                      collapsedExtent: collapsed,
                      sheetColor: sheetColor,
                    ),
                  ),
                  PinnedHeaderSliver(
                    child: ColoredBox(
                      color: sheetColor,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          key: const Key('community-player-controls'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                Text('在线玩家', style: t.titleLarge),
                                SegmentedToggle(
                                  labels: const ['真人', '全部'],
                                  selected: _allPlayers ? 1 : 0,
                                  onChanged: (i) =>
                                      setState(() => _allPlayers = i == 1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: sheetColor,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - collapsed).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (state.communityError != null)
                                ErrorNotice(
                                  '${state.communityError!}${community != null ? ' · 上次数据' : ''}',
                                ),
                              MinecraftPlayers(
                                key: ValueKey(_allPlayers),
                                players: players,
                                available: available,
                              ),
                              const SizedBox(height: 32),
                              Text('KOOK', style: t.titleLarge),
                              const SizedBox(height: 12),
                              if (community == null ||
                                  !community.kookSource.available)
                                EmptyContent(
                                  icon: Icons.headset_off_outlined,
                                  text:
                                      community?.kookSource.error ?? '正在获取语音状态',
                                )
                              else if (community.channels.isEmpty)
                                const EmptyContent(
                                  icon: Icons.headset_outlined,
                                  text: '暂无语音频道',
                                )
                              else
                                for (final channel in community.channels)
                                  _VoiceChannel(channel: channel),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoiceChannel extends StatelessWidget {
  const _VoiceChannel({required this.channel});
  final Json channel;
  @override
  Widget build(BuildContext context) {
    final users = List<Json>.from(channel['users'] as List? ?? []),
        c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volume_up_outlined,
                color: users.isEmpty ? c.onSurfaceVariant : c.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  channel['name']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${users.length}',
                style: TextStyle(color: c.onSurfaceVariant),
              ),
            ],
          ),
          if (users.isNotEmpty)
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
                          PlayerAvatar(u['name']?.toString() ?? '?', size: 28),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              u['name']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
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
    );
  }
}

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider),
        api = ref.read(apiProvider),
        c = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: ref.read(appProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (state.serversError != null) ErrorNotice(state.serversError!),
          if (state.servers.isEmpty && state.serversError == null)
            const EmptyContent(icon: Icons.dns_outlined, text: '暂无托管服务器'),
          ...state.servers.asMap().entries.map((entry) {
            final s = entry.value,
                running =
                    state.hostedStatus['is_running'] == true &&
                    state.hostedStatus['server_name'] == s['name'];
            final known = state.hostedStatus.containsKey('is_running'),
                cover = api.imageUrl(s['img']?.toString());
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MotionReveal(
                child: Card(
                  child: InkWell(
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      sheetAnimationStyle: AnimationStyle(
                        duration: AppMotion.duration(
                          context,
                          AppMotion.standard,
                        ),
                        reverseDuration: AppMotion.duration(
                          context,
                          AppMotion.fast,
                        ),
                      ),
                      builder: (_) => ServerDetails(
                        server: s,
                        running: running,
                        known: known,
                        players: state.hostedPlayers,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cover != null)
                          SizedBox(
                            height: 156,
                            width: double.infinity,
                            child: Ink.image(
                              image: NetworkImage(cover),
                              fit: BoxFit.cover,
                              onImageError: (_, _) {},
                            ),
                          )
                        else
                          Container(
                            height: 104,
                            color: c.secondaryContainer,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.landscape_outlined,
                              size: 48,
                              color: c.onSecondaryContainer,
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
                                      s['name']?.toString() ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  BadgePill(
                                    !known
                                        ? '未知'
                                        : running
                                        ? '运行中'
                                        : '已停止',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cleanMotd(s['motd']?.toString() ?? ''),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.onSurfaceVariant),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Icon(
                                    Icons.extension_outlined,
                                    size: 18,
                                    color: c.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Java ${s['version'] ?? '—'}'),
                                  ),
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: c.primary,
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
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  server['name']?.toString() ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BadgePill(
            !known
                ? '等待运行状态'
                : running
                ? '正在运行'
                : '已停止',
          ),
          const SizedBox(height: 24),
          Text(cleanMotd(server['motd']?.toString() ?? '')),
          const SizedBox(height: 12),
          Text('版本 ${server['version'] ?? '—'}'),
          if (running) ...[
            const Divider(),
            Text(
              '在线玩家 · ${players.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            MinecraftPlayers(players: players, available: true),
          ],
        ],
      ),
    ),
  );
}

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider),
        c = Theme.of(context).colorScheme,
        t = Theme.of(context).textTheme;
    return Column(
      children: [
        if (state.chatError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ErrorNotice(state.chatError!),
          ),
        Expanded(
          child: state.chat.isEmpty
              ? const Center(
                  child: EmptyContent(
                    icon: Icons.chat_bubble_outline,
                    text: '暂无聊天消息',
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  itemCount: state.chat.length,
                  itemBuilder: (context, index) {
                    final msg = state.chat[state.chat.length - 1 - index];
                    if (msg.type == 'join' || msg.type == 'leave') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '${msg.player} ${msg.type == 'join' ? '加入了游戏' : '离开了游戏'} · ${msg.time}',
                          textAlign: TextAlign.center,
                          style: t.labelMedium?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return MotionReveal(
                      key: ValueKey(msg.id ?? identityHashCode(msg)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlayerAvatar(msg.player, size: 36, minecraft: true),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 10,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        msg.player,
                                        style: t.labelLarge?.copyWith(
                                          color: c.primary,
                                        ),
                                      ),
                                      Text(
                                        msg.time,
                                        style: t.labelSmall?.copyWith(
                                          color: c.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.surfaceContainer,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: SelectableText(
                                      msg.message,
                                      style: t.bodyLarge,
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
    final state = ref.watch(appProvider),
        user = state.user!,
        c = Theme.of(context).colorScheme,
        t = Theme.of(context).textTheme;
    final total = state.playtime.fold<num>(
      0,
      (sum, row) => sum + (row['playtime_minutes'] as num? ?? 0),
    );
    final avatar = ref.read(apiProvider).imageUrl(user.avatarUrl);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: '更换头像',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () async {
                        try {
                          await ref.read(appProvider.notifier).uploadAvatar();
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(context, e.toString());
                          }
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.username, style: t.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          user.role == 'admin' ? '社区管理员' : 'Deeraft 成员',
                          style: t.bodyMedium?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: '编辑资料',
                    onPressed: () => showEditProfile(context, ref),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(user.bio, style: t.bodyLarge),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionTitle('游玩时长统计'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '累计游玩',
                style: t.labelLarge?.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                durationLabel(total),
                style: t.headlineLarge?.copyWith(color: c.primary),
              ),
              if (state.playtimeError != null)
                ErrorNotice(state.playtimeError!),
              const SizedBox(height: 20),
              if (state.playtime.isEmpty)
                const EmptyContent(icon: Icons.schedule, text: '还没有存档游玩记录'),
              ...topPlaytime(state.playtime).asMap().entries.map((entry) {
                final p = entry.value;
                final fraction = total > 0
                    ? (p['playtime_minutes'] as num? ?? 0) / total
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${entry.key + 1}',
                            style: t.labelLarge?.copyWith(color: c.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(p['server_name']?.toString() ?? ''),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            durationLabel(p['playtime_minutes'] as num? ?? 0),
                            style: t.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction.clamp(0, 1),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SectionTitle(
          '每日在线',
          action: TextButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(DateFormat('MM.dd').format(state.dailyDate)),
            onPressed: () async {
              final day = await showDatePicker(
                context: context,
                initialDate: state.dailyDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (day != null) ref.read(appProvider.notifier).loadDaily(day);
            },
          ),
        ),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              if (state.dailyError != null) ErrorNotice(state.dailyError!),
              if (state.daily.isEmpty)
                const EmptyContent(icon: Icons.schedule, text: '这一天还没有在线记录'),
              ...state.daily.map(
                (p) => ListTile(
                  leading: PlayerAvatar(
                    p['player']?.toString() ?? '?',
                    minecraft: true,
                  ),
                  title: Text(p['player']?.toString() ?? ''),
                  trailing: Text(
                    durationLabel(p['playtime_minutes'] as num? ?? 0),
                    style: t.labelLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          onPressed: () => ref.read(appProvider.notifier).logout(),
          label: Text(state.demo ? '退出演示' : '退出登录'),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Deeraft · v0.5.0',
            style: t.labelMedium?.copyWith(color: c.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<void> showEditProfile(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.duration(context, AppMotion.standard),
        reverseDuration: AppMotion.duration(context, AppMotion.fast),
      ),
      builder: (_) => const _EditProfileSheet(),
    );

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController name, bio;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final user = ref.read(appProvider).user!;
    name = TextEditingController(text: user.username);
    bio = TextEditingController(text: user.bio);
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().length < 2 ||
        name.text.trim().length > 32 ||
        RegExp(r'\s').hasMatch(name.text.trim())) {
      setState(() => error = '用户名需为 2–32 位且不含空白');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(appProvider.notifier)
          .updateProfile(name.text.trim(), bio.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '编辑个人资料',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: name,
              enabled: !saving,
              maxLength: 32,
              decoration: const InputDecoration(labelText: '用户名'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bio,
              enabled: !saving,
              maxLength: 280,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '个人签名'),
            ),
            if (error != null) ErrorNotice(error!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? '保存中…' : '保存修改'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => MotionReveal(
    child: Card(
      color: color,
      child: MotionSize(
        duration: AppMotion.duration(context, AppMotion.standard),
        curve: AppMotion.curve,
        alignment: Alignment.topCenter,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: onTap == null
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}

class BadgePill extends StatelessWidget {
  const BadgePill(this.label, {super.key, this.color});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: .09) ?? c.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: color ?? c.onSecondaryContainer),
      ),
    );
  }
}

class EmptyContent extends StatelessWidget {
  const EmptyContent({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Material(
        color: c.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: c.onErrorContainer, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: TextStyle(color: c.onErrorContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final c = Theme.of(context).colorScheme;
    if (minecraft) {
      Widget placeholder() => Container(
        width: size,
        height: size,
        color: c.secondaryContainer,
        child: Icon(
          Icons.person_outline,
          size: size * .6,
          color: c.onSecondaryContainer,
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          'https://minotar.net/avatar/${Uri.encodeComponent(name)}/64',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          frameBuilder: (_, child, frame, sync) => Stack(
            children: [placeholder(), if (sync || frame != null) child],
          ),
          errorBuilder: (_, _, _) => placeholder(),
        ),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: c.secondaryContainer,
      foregroundColor: c.onSecondaryContainer,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: size * .38),
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
    if (!widget.available || widget.players.isEmpty) {
      return EmptyContent(
        icon: Icons.people_outline,
        text: widget.available ? '暂无在线玩家' : '暂时无法获取玩家',
      );
    }
    final visible = expanded ? widget.players : widget.players.take(8).toList();
    return Column(
      children: [
        MotionSize(
          duration: AppMotion.duration(context, AppMotion.standard),
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 280 ? 3 : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 20,
                children: visible
                    .map(
                      (name) => SizedBox(
                        width: width,
                        child: Tooltip(
                          message: name,
                          triggerMode: TooltipTriggerMode.tap,
                          child: Column(
                            children: [
                              PlayerAvatar(name, size: 40, minecraft: true),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium,
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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: () => setState(() => expanded = !expanded),
              icon: AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: AppMotion.duration(context, AppMotion.standard),
                child: const Icon(Icons.expand_more),
              ),
              label: Text(expanded ? '收起' : '展开（${widget.players.length}）'),
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
  Widget build(BuildContext context) => SegmentedButton<int>(
    segments: List.generate(
      labels.length,
      (i) => ButtonSegment(value: i, label: Text(labels[i])),
    ),
    selected: {selected},
    showSelectedIcon: false,
    onSelectionChanged: (v) => onChanged(v.first),
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
  );
}
