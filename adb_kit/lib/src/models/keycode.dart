/// A subset of `android.view.KeyEvent.KEYCODE_*` values surfaced as typed
/// constants so IDE autocomplete works. Arbitrary keycode names can still be
/// passed as strings via [InputService.keyEvent].
class KeyCode {
  const KeyCode(this.name);
  final String name;

  @override
  String toString() => name;

  // Navigation
  static const home = KeyCode('KEYCODE_HOME');
  static const back = KeyCode('KEYCODE_BACK');
  static const menu = KeyCode('KEYCODE_MENU');
  static const appSwitch = KeyCode('KEYCODE_APP_SWITCH');
  static const assist = KeyCode('KEYCODE_ASSIST');
  static const search = KeyCode('KEYCODE_SEARCH');
  static const notification = KeyCode('KEYCODE_NOTIFICATION');

  // Media
  static const mediaPlayPause = KeyCode('KEYCODE_MEDIA_PLAY_PAUSE');
  static const mediaPlay = KeyCode('KEYCODE_MEDIA_PLAY');
  static const mediaPause = KeyCode('KEYCODE_MEDIA_PAUSE');
  static const mediaNext = KeyCode('KEYCODE_MEDIA_NEXT');
  static const mediaPrevious = KeyCode('KEYCODE_MEDIA_PREVIOUS');
  static const mediaStop = KeyCode('KEYCODE_MEDIA_STOP');
  static const mediaRewind = KeyCode('KEYCODE_MEDIA_REWIND');
  static const mediaFastForward = KeyCode('KEYCODE_MEDIA_FAST_FORWARD');
  static const mediaRecord = KeyCode('KEYCODE_MEDIA_RECORD');

  // Volume
  static const volumeUp = KeyCode('KEYCODE_VOLUME_UP');
  static const volumeDown = KeyCode('KEYCODE_VOLUME_DOWN');
  static const volumeMute = KeyCode('KEYCODE_VOLUME_MUTE');

  // Power / wake
  static const power = KeyCode('KEYCODE_POWER');
  static const sleep = KeyCode('KEYCODE_SLEEP');
  static const wakeup = KeyCode('KEYCODE_WAKEUP');
  static const softSleep = KeyCode('KEYCODE_SOFT_SLEEP');

  // Telephony
  static const call = KeyCode('KEYCODE_CALL');
  static const endCall = KeyCode('KEYCODE_ENDCALL');
  static const voiceAssist = KeyCode('KEYCODE_VOICE_ASSIST');
  static const headsetHook = KeyCode('KEYCODE_HEADSETHOOK');

  // Camera
  static const camera = KeyCode('KEYCODE_CAMERA');
  static const focus = KeyCode('KEYCODE_FOCUS');

  // Editing
  static const enter = KeyCode('KEYCODE_ENTER');
  static const tab = KeyCode('KEYCODE_TAB');
  static const space = KeyCode('KEYCODE_SPACE');
  static const del = KeyCode('KEYCODE_DEL');
  static const forwardDel = KeyCode('KEYCODE_FORWARD_DEL');
  static const escape = KeyCode('KEYCODE_ESCAPE');
  static const cut = KeyCode('KEYCODE_CUT');
  static const copy = KeyCode('KEYCODE_COPY');
  static const paste = KeyCode('KEYCODE_PASTE');

  // DPAD
  static const dpadUp = KeyCode('KEYCODE_DPAD_UP');
  static const dpadDown = KeyCode('KEYCODE_DPAD_DOWN');
  static const dpadLeft = KeyCode('KEYCODE_DPAD_LEFT');
  static const dpadRight = KeyCode('KEYCODE_DPAD_RIGHT');
  static const dpadCenter = KeyCode('KEYCODE_DPAD_CENTER');
  static const pageUp = KeyCode('KEYCODE_PAGE_UP');
  static const pageDown = KeyCode('KEYCODE_PAGE_DOWN');
  static const moveHome = KeyCode('KEYCODE_MOVE_HOME');
  static const moveEnd = KeyCode('KEYCODE_MOVE_END');

  // Modifiers
  static const shiftLeft = KeyCode('KEYCODE_SHIFT_LEFT');
  static const shiftRight = KeyCode('KEYCODE_SHIFT_RIGHT');
  static const ctrlLeft = KeyCode('KEYCODE_CTRL_LEFT');
  static const ctrlRight = KeyCode('KEYCODE_CTRL_RIGHT');
  static const altLeft = KeyCode('KEYCODE_ALT_LEFT');
  static const altRight = KeyCode('KEYCODE_ALT_RIGHT');
  static const metaLeft = KeyCode('KEYCODE_META_LEFT');
  static const metaRight = KeyCode('KEYCODE_META_RIGHT');

  // System / accessibility
  static const brightnessUp = KeyCode('KEYCODE_BRIGHTNESS_UP');
  static const brightnessDown = KeyCode('KEYCODE_BRIGHTNESS_DOWN');

  /// The full catalogue used in pickers.
  static const all = <KeyCode>[
    home, back, menu, appSwitch, assist, search, notification,
    mediaPlayPause, mediaPlay, mediaPause, mediaNext, mediaPrevious,
    mediaStop, mediaRewind, mediaFastForward, mediaRecord,
    volumeUp, volumeDown, volumeMute,
    power, sleep, wakeup, softSleep,
    call, endCall, voiceAssist, headsetHook,
    camera, focus,
    enter, tab, space, del, forwardDel, escape, cut, copy, paste,
    dpadUp, dpadDown, dpadLeft, dpadRight, dpadCenter,
    pageUp, pageDown, moveHome, moveEnd,
    shiftLeft, shiftRight, ctrlLeft, ctrlRight, altLeft, altRight,
    metaLeft, metaRight, brightnessUp, brightnessDown,
  ];
}
