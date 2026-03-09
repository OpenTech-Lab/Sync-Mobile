import 'package:flutter/widgets.dart';

const int profileUsernameMinLength = 3;
const int profileUsernameMaxLength = 32;

bool isValidProfileUsername(String value) {
  final normalized = value.trim();
  final length = normalized.characters.length;
  if (length < profileUsernameMinLength || length > profileUsernameMaxLength) {
    return false;
  }

  return normalized.runes.every((rune) {
    final isAsciiControl = rune >= 0x00 && rune <= 0x1F;
    final isLatin1Control = rune >= 0x7F && rune <= 0x9F;
    return !isAsciiControl && !isLatin1Control;
  });
}
