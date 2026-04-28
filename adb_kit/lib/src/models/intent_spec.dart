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
  final String flag;
}

class IntentExtra {
  const IntentExtra(this.type, this.key, this.value);
  final IntentExtraType type;
  final String key;
  final String value;
}

/// Structured intent, rendered as `am start|broadcast|startservice` flags.
class IntentSpec {
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

  final String? action;
  final String? data;
  final String? mimeType;
  final List<String> categories;
  final String? component;
  final int? flags;
  final String? packageName;
  final List<IntentExtra> extras;
  final int? user;
  final int? displayId;
  final bool waitForLaunch;

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
