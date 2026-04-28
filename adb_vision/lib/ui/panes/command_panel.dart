import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';

import 'cmd/apps_tab.dart';
import 'cmd/diag_tab.dart';
import 'cmd/files_tab.dart';
import 'cmd/input_tab.dart';
import 'cmd/intents_tab.dart';
import 'cmd/network_tab.dart';
import 'cmd/settings_tab.dart';
import 'cmd/shell_tab.dart';

class CommandPanel extends StatelessWidget {
  const CommandPanel({required this.device, super.key});
  final AdbDevice device;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.touch_app), text: 'Input'),
              Tab(icon: Icon(Icons.apps), text: 'Apps'),
              Tab(icon: Icon(Icons.folder), text: 'Files'),
              Tab(icon: Icon(Icons.terminal), text: 'Shell'),
              Tab(icon: Icon(Icons.send), text: 'Intents'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
              Tab(icon: Icon(Icons.network_check), text: 'Network'),
              Tab(icon: Icon(Icons.bug_report), text: 'Diag'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                InputTab(device: device),
                AppsTab(device: device),
                FilesTab(device: device),
                ShellTab(device: device),
                IntentsTab(device: device),
                SettingsTab(device: device),
                NetworkTab(device: device),
                DiagTab(device: device),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
