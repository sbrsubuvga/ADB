import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'panes/action_log_pane.dart';
import 'panes/command_panel.dart';
import 'panes/device_picker.dart';
import 'panes/logcat_pane.dart';
import 'panes/mirror_view.dart';
import 'panes/scripts_pane.dart';
import 'panes/settings_pane.dart';
import 'responsive.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with TickerProviderStateMixin {
  late final TabController _bottomTabs;
  int _compactIndex = 1;

  @override
  void initState() {
    super.initState();
    _bottomTabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _bottomTabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(selectedDeviceProvider);
    final adbVersion = ref.watch(adbVersionProvider);
    final breakpoint = Breakpoints.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(context, adbVersion, device, breakpoint),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      drawer: breakpoint.isExpanded
          ? null
          : Drawer(
              child: SafeArea(child: DevicePicker()),
            ),
      body: switch (breakpoint) {
        Breakpoint.expanded => _buildExpanded(device),
        Breakpoint.medium => _buildMedium(device),
        Breakpoint.compact => _buildCompact(device),
      },
      bottomNavigationBar: breakpoint.isCompact
          ? NavigationBar(
              selectedIndex: _compactIndex,
              onDestinationSelected: (i) =>
                  setState(() => _compactIndex = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.smartphone), label: 'Mirror'),
                NavigationDestination(
                    icon: Icon(Icons.tune), label: 'Commands'),
                NavigationDestination(
                    icon: Icon(Icons.receipt_long), label: 'Logs'),
              ],
            )
          : null,
    );
  }

  Widget _buildTitle(
    BuildContext context,
    AsyncValue<String> adbVersion,
    AdbDevice? device,
    Breakpoint breakpoint,
  ) {
    final showVersion = breakpoint.isAtLeastMedium;
    final showDeviceChip = breakpoint.isExpanded;
    return Row(
      children: [
        const Icon(Icons.phonelink),
        const SizedBox(width: 8),
        const Flexible(
          child: Text('ADB Vision', overflow: TextOverflow.ellipsis),
        ),
        if (showVersion) ...[
          const SizedBox(width: 16),
          Flexible(
            child: adbVersion.when(
              data: (v) => _versionBadge(context, v.split('\n').first, true),
              loading: () => _versionBadge(context, 'detecting adb…', false),
              error: (_, _) =>
                  _versionBadge(context, 'adb not found', false),
            ),
          ),
        ],
        if (showDeviceChip && device != null) ...[
          const SizedBox(width: 16),
          Flexible(
            child: Chip(
              avatar: Icon(
                device.isReady ? Icons.check_circle : Icons.warning_amber,
                color: device.isReady ? Colors.green : Colors.orange,
                size: 18,
              ),
              label: Text(
                '${device.model ?? device.serial} · ${device.state.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpanded(AdbDevice? device) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              const SizedBox(width: 260, child: DevicePicker()),
              const VerticalDivider(width: 1),
              const Expanded(flex: 3, child: MirrorView()),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 420,
                child: _commandPanelOrEmpty(device),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 300, child: _bottomTabsPanel(device)),
      ],
    );
  }

  Widget _buildMedium(AdbDevice? device) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 3, child: const MirrorView()),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 340,
                child: _commandPanelOrEmpty(device),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 240, child: _bottomTabsPanel(device)),
      ],
    );
  }

  Widget _buildCompact(AdbDevice? device) {
    return IndexedStack(
      index: _compactIndex,
      children: [
        const MirrorView(),
        _commandPanelOrEmpty(device),
        _bottomTabsPanel(device),
      ],
    );
  }

  Widget _commandPanelOrEmpty(AdbDevice? device) {
    if (device == null) {
      return const _EmptyState(
        message: 'Connect a device or emulator to see controls.',
      );
    }
    return CommandPanel(device: device);
  }

  Widget _bottomTabsPanel(AdbDevice? device) {
    return Column(
      children: [
        TabBar(
          controller: _bottomTabs,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Logcat'),
            Tab(icon: Icon(Icons.terminal), text: 'Action Log'),
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Scripts'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _bottomTabs,
            children: [
              device == null
                  ? const _EmptyState(message: 'No device selected.')
                  : LogcatPane(device: device),
              const ActionLogPane(),
              device == null
                  ? const _EmptyState(message: 'No device selected.')
                  : ScriptsPane(device: device),
            ],
          ),
        ),
      ],
    );
  }

  Widget _versionBadge(BuildContext ctx, String text, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (ok ? Colors.green : Colors.red).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

extension AdbDeviceX on AdbDevice {
  String get displayName => model ?? deviceName ?? serial;
}
