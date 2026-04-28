import 'package:adb_kit/adb_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../state/providers.dart';

class Hotbar extends ConsumerWidget {
  const Hotbar({required this.device, super.key});
  final AdbDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(adbKitProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _btn(Icons.arrow_back, 'Back',
              () => kit.input.keyEvent(device.serial, KeyCode.back)),
          _btn(Icons.home, 'Home',
              () => kit.input.keyEvent(device.serial, KeyCode.home)),
          _btn(Icons.more_horiz, 'Recents',
              () => kit.input.keyEvent(device.serial, KeyCode.appSwitch)),
          const VerticalDivider(width: 1),
          _btn(Icons.power_settings_new, 'Power',
              () => kit.input.keyEvent(device.serial, KeyCode.power)),
          _btn(Icons.bedtime_outlined, 'Sleep',
              () => kit.input.keyEvent(device.serial, KeyCode.sleep)),
          _btn(Icons.wb_sunny_outlined, 'Wake',
              () => kit.input.keyEvent(device.serial, KeyCode.wakeup)),
          const VerticalDivider(width: 1),
          _btn(Icons.volume_up, 'Vol +',
              () => kit.input.keyEvent(device.serial, KeyCode.volumeUp)),
          _btn(Icons.volume_down, 'Vol -',
              () => kit.input.keyEvent(device.serial, KeyCode.volumeDown)),
          _btn(Icons.volume_off, 'Mute',
              () => kit.input.keyEvent(device.serial, KeyCode.volumeMute)),
          const VerticalDivider(width: 1),
          _btn(Icons.screen_rotation, 'Rotate', () async {
            final cur = await kit.settings.get(
                device.serial, SettingsNamespace.system, 'user_rotation');
            final next = (int.tryParse(cur) ?? 0 + 1) % 4;
            await kit.settings.put(device.serial, SettingsNamespace.system,
                'user_rotation', '$next');
          }),
          _btn(Icons.photo_camera, 'Screenshot', () async {
            final dir = await getApplicationDocumentsDirectory();
            final path =
                '${dir.path}/adb_vision/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
            await kit.screen.screenshotTo(device.serial, path);
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Saved $path')));
            }
          }),
          _btn(Icons.fiber_manual_record, 'Record', () async {
            final dest = await FilePicker.platform.saveFile(
              dialogTitle: 'Save recording',
              fileName: 'screenrecord.mp4',
              type: FileType.video,
            );
            if (dest == null) return;
            final remote = '/sdcard/screenrecord_tmp.mp4';
            final handle =
                await kit.screen.screenrecord(device.serial, remote);
            if (context.mounted) {
              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Recording…'),
                  content: const Text('Click Stop when done.'),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Stop'),
                    ),
                  ],
                ),
              );
            }
            await handle.kill();
            await Future<void>.delayed(const Duration(seconds: 1));
            await kit.screen.saveRecordingTo(device.serial, remote, dest);
            await kit.files.remove(device.serial, remote);
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Saved $dest')));
            }
          }),
          _btn(Icons.lock, 'Lock screen', () async {
            await kit.power.screenOff(device.serial);
          }),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String tip, VoidCallback action) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tip,
      onPressed: action,
    );
  }
}
