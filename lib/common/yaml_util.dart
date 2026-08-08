import 'package:yaml/yaml.dart';

dynamic yamlToDart(dynamic value) {
  if (value is YamlMap) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(entry.key.toString(), yamlToDart(entry.value)),
      ),
    );
  }
  if (value is YamlList) {
    return value.map(yamlToDart).toList();
  }
  return value;
}

String encodeYaml(dynamic value, {int indent = 0}) {
  final prefix = '  ' * indent;
  if (value == null) {
    return '${prefix}null';
  }
  if (value is bool || value is num) {
    return '$prefix$value';
  }
  if (value is String) {
    return '$prefix${_encodeYamlString(value)}';
  }
  if (value is List) {
    if (value.isEmpty) {
      return '$prefix[]';
    }
    final buffer = StringBuffer();
    for (final item in value) {
      if (item is Map || item is List) {
        buffer.writeln('$prefix-');
        buffer.write(encodeYaml(item, indent: indent + 1));
        if (!buffer.toString().endsWith('\n')) {
          buffer.writeln();
        }
      } else {
        buffer.writeln('$prefix- ${_encodeYamlScalar(item)}');
      }
    }
    return buffer.toString().trimRight();
  }
  if (value is Map) {
    if (value.isEmpty) {
      return '$prefix{}';
    }
    final buffer = StringBuffer();
    for (final entry in value.entries) {
      final key = _encodeYamlKey(entry.key.toString());
      final child = entry.value;
      if (child is Map || child is List) {
        if ((child is Map && child.isEmpty) ||
            (child is List && child.isEmpty)) {
          buffer.writeln('$prefix$key: ${_encodeYamlScalar(child)}');
        } else {
          buffer.writeln('$prefix$key:');
          buffer.writeln(encodeYaml(child, indent: indent + 1));
        }
      } else {
        buffer.writeln('$prefix$key: ${_encodeYamlScalar(child)}');
      }
    }
    return buffer.toString().trimRight();
  }
  return '$prefix${_encodeYamlString(value.toString())}';
}

String _encodeYamlKey(String key) {
  if (key.isEmpty) {
    return "''";
  }
  final needsQuote = RegExp(r'[:#\[\]{},&*!|>%@`]').hasMatch(key) ||
      key.contains(' ') ||
      key.startsWith('*') ||
      key.startsWith('+') ||
      key.startsWith('.') ||
      key.contains('*');
  return needsQuote ? _encodeYamlString(key) : key;
}

String _encodeYamlScalar(dynamic value) {
  if (value == null) {
    return 'null';
  }
  if (value is bool || value is num) {
    return value.toString();
  }
  if (value is List && value.isEmpty) {
    return '[]';
  }
  if (value is Map && value.isEmpty) {
    return '{}';
  }
  return _encodeYamlString(value.toString());
}

String _encodeYamlString(String value) {
  if (value.isEmpty) {
    return "''";
  }
  final needsQuote = RegExp(r'''[\n:#\[\]{},&*!|>%'"]''').hasMatch(value) ||
      value.startsWith(' ') ||
      value.endsWith(' ') ||
      value.startsWith('*') ||
      value.startsWith('+') ||
      value.startsWith('.') ||
      value.contains('*') ||
      value == 'true' ||
      value == 'false' ||
      value == 'null' ||
      num.tryParse(value) != null;
  if (!needsQuote) {
    return value;
  }
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

Map<String, dynamic> parseYamlMap(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('empty yaml');
  }
  final document = loadYaml(trimmed);
  final dartValue = yamlToDart(document);
  if (dartValue is! Map) {
    throw const FormatException('yaml root must be a map');
  }
  return Map<String, dynamic>.from(dartValue);
}
