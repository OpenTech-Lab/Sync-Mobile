import 'dart:io';

import '../l10n/app_localizations.dart';
import '../services/objectionable_content_filter.dart';

/// Classifies [error] into a short, user-friendly message.
///
/// Categories:
/// - Network / connectivity  → check internet
/// - Server error (5xx)     → server trouble, try later
/// - Auth / permission       → contact administrator
/// - Everything else         → generic "try again"
String friendlyErrorMessage(Object error, AppLocalizations l10n) {
  if (error is ObjectionableContentException) {
    return error.message;
  }
  if (_isNetworkError(error)) {
    return l10n.errorNetwork;
  }
  if (_isServerError(error)) {
    return l10n.errorServer;
  }
  if (_isPermissionError(error)) {
    return l10n.errorPermission;
  }
  return l10n.errorGeneric;
}

bool _isNetworkError(Object error) {
  if (error is SocketException) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('socketexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('connection refused') ||
      msg.contains('connection reset') ||
      msg.contains('connection timed out') ||
      msg.contains('network is unreachable') ||
      msg.contains('no address associated') ||
      msg.contains('temporary failure in name resolution') ||
      msg.contains('clientexception') ||
      msg.contains('handshakeexception') ||
      msg.contains('no route to host');
}

bool _isServerError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains(' 500') ||
      msg.contains(' 502') ||
      msg.contains(' 503') ||
      msg.contains(' 504') ||
      msg.contains('internal server error') ||
      msg.contains('bad gateway') ||
      msg.contains('service unavailable');
}

bool _isPermissionError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains(' 401') ||
      msg.contains(' 403') ||
      msg.contains('unauthorized') ||
      msg.contains('forbidden');
}
