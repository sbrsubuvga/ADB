/// Typed `--ex*` flag families understood by `am start`.
enum IntentExtraType {
  string('--es'),
  int_('--ei'),
  bool_('--ez'),
  long_('--el'),
  float_('--ef'),
  uri('--eu'),
  component('--ecn'),
  intArray('--eia'),
  stringArray('--esa'),
  longArray('--ela'),
  booleanArray('--eza');

  const IntentExtraType(this.flag);

  /// The `--e*` command-line flag passed to `am`.
  final String flag;
}

/// A single `extra` key/value pair on an [IntentSpec].
class IntentExtra {
  /// Creates an [IntentExtra].
  const IntentExtra(this.type, this.key, this.value);

  /// Wire type used to encode [value].
  final IntentExtraType type;

  /// Extra name.
  final String key;

  /// Extra value as a string (parsed by `am` according to [type]).
  final String value;
}

/// Structured intent, rendered as `am start|broadcast|startservice` flags.
class IntentSpec {
  /// Creates an [IntentSpec].
  const IntentSpec({
    this.action,
    this.data,
    this.mimeType,
    this.categories = const [],
    this.component,
    this.flags,
    this.packageName,
    this.extras = const [],
    this.user,
    this.displayId,
    this.waitForLaunch = false,
  });

  /// Intent action (`-a`).
  final String? action;

  /// Intent data URI (`-d`).
  final String? data;

  /// MIME type (`-t`).
  final String? mimeType;

  /// Intent categories (`-c`).
  final List<String> categories;

  /// Explicit component name `pkg/.Activity` (`-n`).
  final String? component;

  /// Raw intent flags bitmask (`-f`).
  final int? flags;

  /// Restrict resolution to a single package (`-p`).
  final String? packageName;

  /// Typed extras to attach to the intent.
  final List<IntentExtra> extras;

  /// Target user id (`--user`).
  final int? user;

  /// Target display id (`--display`).
  final int? displayId;

  /// Whether to pass `-W` to wait for launch.
  final bool waitForLaunch;

  /// Renders this intent as the trailing args for `am start|broadcast|...`.
  List<String> toArgs() {
    final args = <String>[];
    if (action != null) args.addAll(['-a', action!]);
    if (data != null) args.addAll(['-d', data!]);
    if (mimeType != null) args.addAll(['-t', mimeType!]);
    for (final c in categories) {
      args.addAll(['-c', c]);
    }
    if (component != null) args.addAll(['-n', component!]);
    if (flags != null) args.addAll(['-f', flags.toString()]);
    if (packageName != null) args.addAll(['-p', packageName!]);
    if (user != null) args.addAll(['--user', '$user']);
    if (displayId != null) args.addAll(['--display', '$displayId']);
    if (waitForLaunch) args.add('-W');
    for (final e in extras) {
      args.addAll([e.type.flag, e.key, e.value]);
    }
    return args;
  }
}
