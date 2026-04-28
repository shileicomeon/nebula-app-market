import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const AppMarketApp());
}

class AppMarketApp extends StatelessWidget {
  const AppMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF236CFF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '星云应用市场',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        useMaterial3: true,
        textTheme: Typography.blackCupertino.apply(fontFamilyFallback: const [
          'PingFang SC',
          'Microsoft YaHei',
          'Noto Sans CJK SC',
        ]),
      ),
      home: const StoreShell(),
    );
  }
}

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int _index = 0;
  List<StoreApp> _apps = StoreApp.seed;
  String _status = '离线精品数据';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await AppStoreApi()
          .fetchApps()
          .timeout(const Duration(milliseconds: 1600));
      if (!mounted || apps.isEmpty) return;
      setState(() {
        _apps = apps;
        _status = '已连接 Go 后端';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Go 后端未启动，使用离线数据');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(apps: _apps, status: _status),
      RankingPage(apps: _apps),
      CategoryPage(apps: _apps),
      const ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        indicatorColor: const Color(0xFFE7EFFF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: '排行',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: '分类',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.apps, required this.status});

  final List<StoreApp> apps;
  final String status;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _keyword = '';
  String? _category;
  int _featureOffset = 0;

  @override
  Widget build(BuildContext context) {
    final filteredApps = widget.apps.where((app) {
      if (_category != null && app.category != _category) return false;
      if (_keyword.trim().isEmpty) return true;
      final keyword = _keyword.toLowerCase();
      return app.name.toLowerCase().contains(keyword) ||
          app.category.toLowerCase().contains(keyword) ||
          app.tags.any((tag) => tag.toLowerCase().contains(keyword));
    }).toList();
    final featuredPool = filteredApps.isEmpty ? widget.apps : filteredApps;
    final featured = [
      for (var index = 0; index < featuredPool.length && index < 3; index++)
        featuredPool[(index + _featureOffset) % featuredPool.length]
    ];
    final popular = [...filteredApps]
      ..sort((a, b) => b.downloads.compareTo(a.downloads));

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchHeaderDelegate(
              status: widget.status,
              onChanged: (value) => setState(() => _keyword = value),
              onScanTap: () => showAppSnack(context, '扫一扫功能已打开'),
              onNotifyTap: () => showAppSnack(context, '暂无新的应用更新提醒'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryShortcuts(
                    selected: _category,
                    onSelected: (category) => setState(() {
                      _category = _category == category ? null : category;
                    }),
                  ),
                  if (_category != null || _keyword.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FilterSummary(
                      label: _category ?? '搜索：$_keyword',
                      onClear: () => setState(() {
                        _category = null;
                        _keyword = '';
                      }),
                    ),
                  ],
                  const SizedBox(height: 18),
                  HeroBanner(
                    app: featured.first,
                    onTap: () => openDetail(context, featured.first),
                  ),
                  const SizedBox(height: 24),
                  SectionTitle(
                    title: '今日精品',
                    action: '换一批',
                    onTap: () => setState(() => _featureOffset++),
                  ),
                  const SizedBox(height: 12),
                  FeaturedStrip(apps: featured),
                  const SizedBox(height: 22),
                  SectionTitle(
                    title: '热门应用',
                    action: '全部',
                    onTap: () => setState(() {
                      _category = null;
                      _keyword = '';
                    }),
                  ),
                ],
              ),
            ),
          ),
          if (popular.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(message: '没有找到匹配的应用，换个关键词试试'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              sliver: SliverList.separated(
                itemCount: popular.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => AppListTile(
                  app: popular[index],
                  rank: index + 1,
                  onTap: () => openDetail(context, popular[index]),
                  onInstall: () =>
                      showAppSnack(context, '${popular[index].name} 已加入下载队列'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StoreHeader extends StatelessWidget {
  const StoreHeader({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '星云应用市场',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.verified_user,
                      size: 15, color: Color(0xFF0EAF74)),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style:
                        const TextStyle(color: Color(0xFF667085), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: softShadow,
          ),
          child: const Icon(Icons.notifications_none, color: Color(0xFF236CFF)),
        ),
      ],
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.onChanged,
    this.onScanTap,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback? onScanTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: softShadow,
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '搜索应用、游戏、专题',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            onPressed: onScanTap,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        ),
      ),
    );
  }
}

class CategoryShortcuts extends StatelessWidget {
  const CategoryShortcuts(
      {super.key, required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      ShortcutItem('游戏', Icons.sports_esports, Color(0xFFFF7A45)),
      ShortcutItem('工具', Icons.construction, Color(0xFF236CFF)),
      ShortcutItem('影音', Icons.play_circle, Color(0xFF8B5CF6)),
      ShortcutItem('学习', Icons.school, Color(0xFF0EAF74)),
      ShortcutItem('办公', Icons.work, Color(0xFF0EA5E9)),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items.map((item) {
        final isSelected = item.label == selected;
        return InkWell(
          onTap: () => onSelected(item.label),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected ? item.color : item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected ? softShadow : null,
                ),
                child: Icon(item.icon,
                    color: isSelected ? Colors.white : item.color),
              ),
              const SizedBox(height: 7),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? item.color : const Color(0xFF344054),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const SearchHeaderDelegate({
    required this.status,
    required this.onChanged,
    required this.onScanTap,
    required this.onNotifyTap,
  });

  final String status;
  final ValueChanged<String> onChanged;
  final VoidCallback onScanTap;
  final VoidCallback onNotifyTap;

  @override
  double get minExtent => 74;

  @override
  double get maxExtent => 74;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: const Color(0xFFF5F7FB).withOpacity(0.96),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: Row(
            children: [
              Expanded(
                  child: SearchBox(onChanged: onChanged, onScanTap: onScanTap)),
              const SizedBox(width: 10),
              InkWell(
                onTap: onNotifyTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: softShadow,
                  ),
                  child: const Icon(Icons.notifications_none,
                      color: Color(0xFF236CFF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SearchHeaderDelegate oldDelegate) {
    return status != oldDelegate.status;
  }
}

class FilterSummary extends StatelessWidget {
  const FilterSummary({super.key, required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Color(0xFF236CFF)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF236CFF), fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
              onTap: onClear,
              child:
                  const Icon(Icons.close, size: 16, color: Color(0xFF236CFF))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56, color: Color(0xFF98A2B3)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF667085))),
          ],
        ),
      ),
    );
  }
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.app, required this.onTap});

  final StoreApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF236CFF), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF236CFF).withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -28,
              child: CircleAvatar(
                  radius: 78, backgroundColor: Colors.white.withOpacity(0.10)),
            ),
            Positioned(
              right: 26,
              bottom: 18,
              child: AppIcon(app: app, size: 76, elevated: false),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('新机装机必备',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const Spacer(),
                  const Text(
                    '安全下载 · 精品推荐',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${app.name} 等 ${StoreApp.seed.length}+ 款高分应用已通过人工复检',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.84), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryAppsPage extends StatelessWidget {
  const CategoryAppsPage({
    super.key,
    required this.category,
    required this.apps,
  });

  final String category;
  final List<StoreApp> apps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$category精选')),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: apps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => AppListTile(
          app: apps[index],
          rank: index + 1,
          onTap: () => openDetail(context, apps[index]),
          onInstall: () => showAppSnack(context, '${apps[index].name} 已加入下载队列'),
        ),
      ),
    );
  }
}

class SimpleInfoPage extends StatelessWidget {
  const SimpleInfoPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: const Color(0xFF236CFF)),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFF667085), height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturedStrip extends StatelessWidget {
  const FeaturedStrip({super.key, required this.apps});

  final List<StoreApp> apps;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: apps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => FeaturedCard(
          app: apps[index],
          onTap: () => openDetail(context, apps[index]),
        ),
      ),
    );
  }
}

class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.app, required this.onTap});

  final StoreApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(app: app, size: 48),
            const Spacer(),
            Text(app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(app.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
          ],
        ),
      ),
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.app,
    required this.rank,
    required this.onTap,
    required this.onInstall,
    this.actionLabel,
  });

  final StoreApp app;
  final int rank;
  final VoidCallback onTap;
  final VoidCallback onInstall;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: softShadow,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF98A2B3), fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            AppIcon(app: app, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (app.verified) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.verified,
                            size: 16, color: Color(0xFF0EAF74)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${app.category} · ${app.size} · ${app.rating.toStringAsFixed(1)} 分',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InstallButton(
                label: actionLabel ?? (rank <= 2 ? '安装' : '获取'),
                onPressed: onInstall),
          ],
        ),
      ),
    );
  }
}

class RankingPage extends StatefulWidget {
  const RankingPage({super.key, required this.apps});

  final List<StoreApp> apps;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  int _selected = 0;
  static const _tabs = ['热门榜', '新品榜', '飙升榜', '游戏榜'];

  List<StoreApp> get _ranked {
    final items = [...widget.apps];
    switch (_selected) {
      case 1:
        items.sort((a, b) => b.id.compareTo(a.id));
      case 2:
        items.sort((a, b) =>
            (b.rating * b.downloads).compareTo(a.rating * a.downloads));
      case 3:
        items.retainWhere((app) => app.category == '游戏');
        items.sort((a, b) => b.rating.compareTo(a.rating));
      default:
        items.sort((a, b) => b.downloads.compareTo(a.downloads));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeading(title: '排行榜', subtitle: '高分、飙升、新品一屏掌握'),
            const SizedBox(height: 16),
            RankingTabs(
              tabs: _tabs,
              selected: _selected,
              onSelected: (index) => setState(() => _selected = index),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ranked.isEmpty
                  ? const EmptyState(message: '这个榜单暂时没有应用')
                  : ListView.separated(
                      itemCount: ranked.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => AppListTile(
                        app: ranked[index],
                        rank: index + 1,
                        onTap: () => openDetail(context, ranked[index]),
                        onInstall: () => showAppSnack(
                            context, '${ranked[index].name} 已加入下载队列'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class RankingTabs extends StatelessWidget {
  const RankingTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ChoiceChip(
          label: Text(tabs[index]),
          selected: selected == index,
          onSelected: (_) => onSelected(index),
          side: BorderSide.none,
          selectedColor: const Color(0xFF236CFF),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: selected == index ? Colors.white : const Color(0xFF344054),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key, required this.apps});

  final List<StoreApp> apps;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<StoreApp>>{};
    for (final app in apps) {
      grouped.putIfAbsent(app.category, () => []).add(app);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeading(title: '分类', subtitle: '按场景找到最适合的应用'),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.05,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final entry = grouped.entries.elementAt(index);
                  return CategoryCard(
                    category: entry.key,
                    apps: entry.value,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoryAppsPage(
                            category: entry.key, apps: entry.value),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.apps,
    required this.onTap,
  });

  final String category;
  final List<StoreApp> apps;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(category);
    final topApps = apps.map((app) => app.name).take(2).join('、');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(iconFor(category), color: color),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
              ],
            ),
            const Spacer(),
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${apps.length} 款精选应用',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 4),
            Text(
              topApps.isEmpty ? '暂无推荐' : topApps,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        children: [
          const PageHeading(title: '我的', subtitle: '下载、更新、隐私权限统一管理'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF101828), Color(0xFF344054)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('欢迎回来',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                      SizedBox(height: 4),
                      Text('3 个应用可更新，2 个预约即将上线',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                InstallButton(
                  label: '登录',
                  dark: true,
                  onPressed: () => showLoginSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ProfileAction(
            icon: Icons.system_update_alt,
            title: '应用更新',
            subtitle: '3 个应用可更新',
            badge: '3',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppUpdatesPage())),
          ),
          ProfileAction(
            icon: Icons.downloading,
            title: '下载管理',
            subtitle: '2 个任务下载中',
            badge: '2',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadManagerPage())),
          ),
          ProfileAction(
            icon: Icons.shield_outlined,
            title: '隐私与权限',
            subtitle: '查看敏感权限调用',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PrivacyPermissionsPage())),
          ),
          ProfileAction(
            icon: Icons.favorite_border,
            title: '收藏与预约',
            subtitle: '收藏应用与新游预约',
            badge: '5',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FavoritesPage())),
          ),
          ProfileAction(
            icon: Icons.settings_outlined,
            title: '设置',
            subtitle: '自动更新、网络、缓存',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }
}

class ProfileAction extends StatelessWidget {
  const ProfileAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: softShadow),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF236CFF)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF667085))),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFEEF0),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Color(0xFFE11D48),
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
          ],
        ),
      ),
    );
  }
}

class AppUpdatesPage extends StatefulWidget {
  const AppUpdatesPage({super.key});

  @override
  State<AppUpdatesPage> createState() => _AppUpdatesPageState();
}

class _AppUpdatesPageState extends State<AppUpdatesPage> {
  final Set<int> _updated = {};

  @override
  Widget build(BuildContext context) {
    final apps = StoreApp.seed.take(3).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('应用更新')),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: apps.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return SummaryCard(
                icon: Icons.system_update_alt,
                title: '可更新 ${apps.length - _updated.length} 个应用',
                subtitle: '建议在 Wi‑Fi 环境下自动更新');
          }
          final app = apps[index - 1];
          final done = _updated.contains(app.id);
          return AppListTile(
            app: app,
            rank: index,
            onTap: () => openDetail(context, app),
            onInstall: () => setState(() => _updated.add(app.id)),
            actionLabel: done ? '已更新' : '更新',
          );
        },
      ),
    );
  }
}

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final List<DownloadTask> _tasks = [
    DownloadTask(StoreApp.seed[1], 0.64, false),
    DownloadTask(StoreApp.seed[2], 0.32, true),
    DownloadTask(StoreApp.seed[3], 1.0, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下载管理')),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: softShadow),
            child: Row(
              children: [
                AppIcon(app: task.app, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(99)),
                      const SizedBox(height: 6),
                      Text(
                          task.progress >= 1
                              ? '下载完成，可安装'
                              : task.paused
                                  ? '已暂停 · ${(task.progress * 100).round()}%'
                                  : '下载中 · ${(task.progress * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF667085))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => setState(() {
                    if (task.progress >= 1) {
                      showAppSnack(context, '${task.app.name} 开始安装');
                    } else {
                      task.paused = !task.paused;
                    }
                  }),
                  icon: Icon(task.progress >= 1
                      ? Icons.install_mobile
                      : task.paused
                          ? Icons.play_arrow
                          : Icons.pause),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PrivacyPermissionsPage extends StatefulWidget {
  const PrivacyPermissionsPage({super.key});

  @override
  State<PrivacyPermissionsPage> createState() => _PrivacyPermissionsPageState();
}

class _PrivacyPermissionsPageState extends State<PrivacyPermissionsPage> {
  final Map<String, bool> _enabled = {
    '定位权限': true,
    '相机权限': false,
    '麦克风权限': false,
    '通讯录权限': false
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与权限')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SummaryCard(
              icon: Icons.shield,
              title: '隐私风险良好',
              subtitle: '所有应用均已通过权限说明与安全检测'),
          const SizedBox(height: 12),
          for (final entry in _enabled.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: softShadow),
              child: SwitchListTile(
                value: entry.value,
                onChanged: (value) =>
                    setState(() => _enabled[entry.key] = value),
                title: Text(entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(valueText(entry.value),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _showReservations = false;
  final Set<int> _removed = {};

  @override
  Widget build(BuildContext context) {
    final apps = (_showReservations
            ? StoreApp.seed
                .where((app) => app.category == '游戏' || app.tags.contains('预约'))
            : StoreApp.seed.take(4))
        .where((app) => !_removed.contains(app.id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('收藏与预约')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('收藏')),
                ButtonSegment(value: true, label: Text('预约'))
              ],
              selected: {_showReservations},
              onSelectionChanged: (value) =>
                  setState(() => _showReservations = value.first),
            ),
          ),
          Expanded(
            child: apps.isEmpty
                ? const EmptyState(message: '这里暂时空空如也')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    itemCount: apps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => AppListTile(
                      app: apps[index],
                      rank: index + 1,
                      onTap: () => openDetail(context, apps[index]),
                      onInstall: () =>
                          setState(() => _removed.add(apps[index].id)),
                      actionLabel: _showReservations ? '取消预约' : '移除',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoUpdate = true;
  bool _wifiOnly = true;
  bool _notifications = true;
  String _cache = '128 MB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SettingsSwitchTile(
              title: '自动更新',
              subtitle: '应用空闲时自动下载安装包',
              value: _autoUpdate,
              onChanged: (value) => setState(() => _autoUpdate = value)),
          SettingsSwitchTile(
              title: '仅 Wi‑Fi 下载',
              subtitle: '避免使用移动网络下载大文件',
              value: _wifiOnly,
              onChanged: (value) => setState(() => _wifiOnly = value)),
          SettingsSwitchTile(
              title: '更新提醒',
              subtitle: '有新版或预约上线时通知我',
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value)),
          InkWell(
            onTap: () => setState(() => _cache = '0 MB'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: softShadow),
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services_outlined,
                      color: Color(0xFF236CFF)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('清理缓存（$_cache）',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900))),
                  const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: softShadow),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: softShadow),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF236CFF), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF667085))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadTask {
  DownloadTask(this.app, this.progress, this.paused,
      {this.id = 0, this.status = 'downloading'});

  final StoreApp app;
  final double progress;
  bool paused;
  final int id;
  String status;

  String get statusText {
    if (progress >= 1) return status == 'installing' ? '正在安装' : '下载完成，可安装';
    if (paused) return '已暂停 · ${(progress * 100).round()}%';
    return '下载中 · ${(progress * 100).round()}%';
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      StoreApp.fromJson(json['app'] as Map<String, dynamic>? ?? const {}),
      (json['progress'] as num? ?? 0).toDouble(),
      json['paused'] as bool? ?? false,
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? 'downloading',
    );
  }
}

class UserSettings {
  const UserSettings(
      {required this.autoUpdate,
      required this.wifiOnly,
      required this.notifications});

  final bool autoUpdate;
  final bool wifiOnly;
  final bool notifications;

  UserSettings copyWith(
      {bool? autoUpdate, bool? wifiOnly, bool? notifications}) {
    return UserSettings(
      autoUpdate: autoUpdate ?? this.autoUpdate,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      notifications: notifications ?? this.notifications,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      autoUpdate: json['auto_update'] as bool? ?? true,
      wifiOnly: json['wifi_only'] as bool? ?? true,
      notifications: json['notifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'auto_update': autoUpdate,
        'wifi_only': wifiOnly,
        'notifications': notifications,
      };
}

String valueText(bool enabled) => enabled ? '允许，点击可关闭' : '未开启，点击可授权';

void showLoginSheet(BuildContext context) {
  final controller = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
          22, 8, 22, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('手机号登录',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone_android),
                  hintText: '请输入手机号',
                  border: OutlineInputBorder())),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final phone = controller.text.trim();
                if (phone.isEmpty) {
                  showAppSnack(context, '请先输入手机号');
                  return;
                }
                Navigator.of(sheetContext).pop();
                try {
                  await AppStoreApi().login(phone);
                  if (context.mounted) showAppSnack(context, '登录成功，数据已同步到后端');
                } catch (_) {
                  if (context.mounted) showAppSnack(context, '验证码已发送（离线演示）');
                }
              },
              child: const Text('获取验证码'),
            ),
          ),
        ],
      ),
    ),
  );
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.app});

  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: const Color(0xFF236CFF),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [colorFor(app.category), const Color(0xFF111827)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 74, 22, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppIcon(app: app, size: 86, elevated: false),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(app.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(app.developer,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 10),
                              Wrap(
                                  spacing: 6,
                                  children: app.tags
                                      .take(3)
                                      .map((tag) => DetailTag(tag))
                                      .toList()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: StatPill(
                              value: app.rating.toStringAsFixed(1),
                              label: '评分')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: StatPill(
                              value: '${app.downloads}万', label: '下载')),
                      const SizedBox(width: 10),
                      Expanded(child: StatPill(value: app.size, label: '大小')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: InstallButton(
                      label: '安全安装',
                      large: true,
                      onPressed: () =>
                          showAppSnack(context, '${app.name} 已加入下载队列'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionTitle(
                    title: '应用截图',
                    action: '3 张',
                    onTap: () => showAppSnack(context, '点击下方截图可预览'),
                  ),
                  const SizedBox(height: 12),
                  ScreenshotStrip(app: app),
                  const SizedBox(height: 24),
                  SectionTitle(
                    title: '应用介绍',
                    action: '展开',
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => Padding(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                        child: SingleChildScrollView(
                          child: Text(app.description,
                              style: const TextStyle(height: 1.7)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(app.description,
                      style: const TextStyle(
                          height: 1.65, color: Color(0xFF475467))),
                  const SizedBox(height: 22),
                  SecurityCard(app: app),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenshotStrip extends StatelessWidget {
  const ScreenshotStrip({super.key, required this.app});

  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: app.screenshots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(app.screenshots[index]),
              content: AspectRatio(
                aspectRatio: 0.72,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [colorFor(app.category), const Color(0xFFFFFFFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Icon(iconFor(app.category),
                      size: 72, color: Colors.white),
                ),
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 104,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  colorFor(app.category).withOpacity(0.85),
                  const Color(0xFFFFFFFF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                Icon(iconFor(app.category), color: Colors.white, size: 32),
                const Spacer(),
                Text(
                  app.screenshots[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecurityCard extends StatelessWidget {
  const SecurityCard({super.key, required this.app});

  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield, color: Color(0xFF0EAF74)),
              SizedBox(width: 8),
              Text('安全检测',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text('已完成病毒扫描、隐私合规、权限说明复检。当前版本 ${app.version}，支持官方签名校验。',
              style: const TextStyle(color: Color(0xFF667085), height: 1.55)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
      {super.key, required this.title, required this.action, this.onTap});

  final String title;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827)))),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(action,
                style: const TextStyle(
                    color: Color(0xFF236CFF), fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF667085))),
      ],
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(
      {super.key, required this.app, required this.size, this.elevated = true});

  final StoreApp app;
  final double size;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
            colors: [colorFor(app.category), colorFor(app.name)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: elevated ? softShadow : null,
      ),
      child:
          Icon(iconFor(app.category), color: Colors.white, size: size * 0.48),
    );
  }
}

class InstallButton extends StatelessWidget {
  const InstallButton(
      {super.key,
      required this.label,
      this.dark = false,
      this.large = false,
      this.onPressed});

  final String label;
  final bool dark;
  final bool large;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: dark ? Colors.white : const Color(0xFF236CFF),
        foregroundColor: dark ? const Color(0xFF111827) : Colors.white,
        padding: EdgeInsets.symmetric(
            horizontal: large ? 22 : 16, vertical: large ? 16 : 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(large ? 18 : 999)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: softShadow),
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
        ],
      ),
    );
  }
}

class DetailTag extends StatelessWidget {
  const DetailTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
}

void openDetail(BuildContext context, StoreApp app) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => DetailPage(app: app)));
}

Color colorFor(String value) {
  final colors = [
    const Color(0xFF236CFF),
    const Color(0xFF8B5CF6),
    const Color(0xFFFF7A45),
    const Color(0xFF0EAF74),
    const Color(0xFF0EA5E9),
    const Color(0xFFEC4899),
  ];
  return colors[
      value.runes.fold<int>(0, (sum, code) => sum + code) % colors.length];
}

IconData iconFor(String category) {
  return switch (category) {
    '游戏' => Icons.sports_esports,
    '工具' => Icons.construction,
    '影音' => Icons.play_circle,
    '学习' => Icons.school,
    '办公' => Icons.work,
    '社交' => Icons.people_alt,
    _ => Icons.apps,
  };
}

const softShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
];

class ShortcutItem {
  const ShortcutItem(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class StoreApp {
  const StoreApp({
    required this.id,
    required this.name,
    required this.category,
    required this.summary,
    required this.description,
    required this.rating,
    required this.size,
    required this.downloads,
    required this.verified,
    required this.tags,
    required this.screenshots,
    required this.developer,
    required this.version,
  });

  final int id;
  final String name;
  final String category;
  final String summary;
  final String description;
  final double rating;
  final String size;
  final int downloads;
  final bool verified;
  final List<String> tags;
  final List<String> screenshots;
  final String developer;
  final String version;

  factory StoreApp.fromJson(Map<String, dynamic> json) {
    return StoreApp(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '未知应用',
      category: json['category'] as String? ?? '工具',
      summary: json['summary'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rating: (json['rating'] as num? ?? 4.5).toDouble(),
      size: json['size'] as String? ?? '68MB',
      downloads: json['downloads'] as int? ?? 0,
      verified: json['verified'] as bool? ?? true,
      tags: List<String>.from(json['tags'] as List? ?? const ['精选']),
      screenshots: List<String>.from(
          json['screenshots'] as List? ?? const ['首页', '详情', '安全']),
      developer: json['developer'] as String? ?? '官方开发者',
      version: json['version'] as String? ?? '1.0.0',
    );
  }

  static const seed = [
    StoreApp(
      id: 1,
      name: '云记笔记',
      category: '办公',
      summary: '多端同步的高效记录工具',
      description:
          '云记笔记支持 Markdown、图片、语音和待办清单，适合会议记录、学习整理和项目协作。应用通过隐私合规检测，默认不开启敏感权限。',
      rating: 4.9,
      size: '86MB',
      downloads: 1280,
      verified: true,
      tags: ['效率', '同步', '办公'],
      screenshots: ['智能编辑', '云端同步', '团队协作'],
      developer: 'Blue Cloud Studio',
      version: '3.8.2',
    ),
    StoreApp(
      id: 2,
      name: '星球旅人',
      category: '游戏',
      summary: '轻科幻放置冒险手游',
      description: '星球旅人以低门槛放置玩法和精致星际美术为核心，支持离线收益、角色养成和好友互助。',
      rating: 4.8,
      size: '512MB',
      downloads: 960,
      verified: true,
      tags: ['新游', '冒险', '预约'],
      screenshots: ['星际地图', '角色养成', '组队探索'],
      developer: 'Nebula Games',
      version: '1.4.0',
    ),
    StoreApp(
      id: 3,
      name: '轻剪辑',
      category: '影音',
      summary: '手机也能快速做大片',
      description: '轻剪辑提供模板剪辑、字幕识别、封面设计和一键导出能力，适合短视频创作者快速完成内容生产。',
      rating: 4.7,
      size: '142MB',
      downloads: 2280,
      verified: true,
      tags: ['视频', '模板', '创作'],
      screenshots: ['模板中心', '字幕识别', '高清导出'],
      developer: 'Light Cut Team',
      version: '6.2.1',
    ),
    StoreApp(
      id: 4,
      name: '隐私管家',
      category: '工具',
      summary: '权限检测与风险提醒',
      description: '隐私管家帮助用户识别敏感权限、后台唤醒和风险行为，提供清晰的权限解释与关闭建议。',
      rating: 4.6,
      size: '34MB',
      downloads: 1730,
      verified: true,
      tags: ['安全', '权限', '清理'],
      screenshots: ['权限雷达', '风险报告', '一键优化'],
      developer: 'SafeLab',
      version: '2.5.7',
    ),
    StoreApp(
      id: 5,
      name: '每日英语',
      category: '学习',
      summary: '碎片时间练听说读写',
      description: '每日英语提供词汇计划、情景听力、AI 跟读评分和学习打卡，帮助用户保持稳定学习节奏。',
      rating: 4.9,
      size: '118MB',
      downloads: 890,
      verified: true,
      tags: ['英语', '打卡', '口语'],
      screenshots: ['词汇计划', '口语评分', '学习日历'],
      developer: 'Daily Learn Inc.',
      version: '5.1.3',
    ),
    StoreApp(
      id: 6,
      name: '邻里圈',
      category: '社交',
      summary: '发现附近生活与兴趣小组',
      description: '邻里圈聚合本地活动、二手交易和兴趣小组，支持实名认证与内容安全审核。',
      rating: 4.5,
      size: '76MB',
      downloads: 740,
      verified: true,
      tags: ['社区', '本地', '兴趣'],
      screenshots: ['附近动态', '兴趣小组', '活动报名'],
      developer: 'Local Link',
      version: '2.9.0',
    ),
  ];
}

class AppStoreApi {
  AppStoreApi({this.baseUrl = 'http://10.0.2.2:8080'});

  final String baseUrl;

  Future<List<StoreApp>> fetchApps() async {
    final jsonBody = await _getMap('/api/apps');
    return _appsFrom(jsonBody);
  }

  Future<List<StoreApp>> fetchUpdates() async {
    final jsonBody = await _getMap('/api/me/updates');
    return _appsFrom(jsonBody);
  }

  Future<List<StoreApp>> fetchRelation(String relation) async {
    final jsonBody = await _getMap('/api/me/$relation');
    return _appsFrom(jsonBody);
  }

  Future<void> deleteRelation(String relation, int appId) async {
    await _send('/api/me/$relation/$appId', method: 'DELETE');
  }

  Future<UserSettings> fetchSettings() async {
    return UserSettings.fromJson(await _getMap('/api/me/settings'));
  }

  Future<void> updateSettings(UserSettings settings) async {
    await _send('/api/me/settings', method: 'PUT', body: settings.toJson());
  }

  Future<List<DownloadTask>> fetchDownloads() async {
    final jsonBody = await _getMap('/api/me/downloads');
    return (jsonBody['downloads'] as List? ?? const [])
        .map((item) => DownloadTask.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleDownload(int id) async {
    await _send('/api/me/downloads', method: 'POST', body: {'id': id});
  }

  Future<void> createDownload(int appId) async {
    await _send('/api/me/downloads', method: 'POST', body: {'app_id': appId});
  }

  Future<Map<String, dynamic>> login(String phone) async {
    return _send('/api/auth/login', method: 'POST', body: {'phone': phone});
  }

  List<StoreApp> _appsFrom(Map<String, dynamic> jsonBody) {
    return (jsonBody['apps'] as List? ?? const [])
        .map((item) => StoreApp.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _getMap(String path) {
    return _send(path, method: 'GET');
  }

  Future<Map<String, dynamic>> _send(
    String path, {
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(text, uri: Uri.parse('$baseUrl$path'));
      }
      if (text.trim().isEmpty) return const {};
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}
