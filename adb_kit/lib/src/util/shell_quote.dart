/// Safely quote a single argument for `adb shell ...` where the binary
/// concatenates all args into one remote shell command line. Always prefer
/// passing structured args over this helper.
String shellQuote(String input) {
  if (input.isEmpty) return "''";
  if (RegExp(r'^[A-Za-z0-9_\-:/\.@,=\+]+$').hasMatch(input)) return input;
  return "'${input.replaceAll("'", r"'\''")}'";
}

/// Join a list of args with [shellQuote].
String shellJoin(Iterable<String> parts) => parts.map(shellQuote).join(' ');
