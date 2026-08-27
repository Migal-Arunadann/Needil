class ErrorFormatter {
  /// Checks whether an exception or error message represents a network / connectivity / offline issue.
  static bool isNetworkError(Object? error) {
    if (error == null) return false;
    final str = error.toString().toLowerCase();

    return str.contains('failed to fetch') ||
        str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('connection reset') ||
        str.contains('connection closed') ||
        str.contains('network is unreachable') ||
        str.contains('networkerror') ||
        str.contains('isabort: true') ||
        str.contains('statuscode: 0') ||
        str.contains('status: 0') ||
        str.contains('xmlhttprequest error') ||
        str.contains('timeoutexception') ||
        str.contains('handshakeexception') ||
        str.contains('failed host lookup') ||
        str.contains('net::err_') ||
        str.contains('clientexception: failed to fetch') ||
        str.contains('offline') ||
        str.contains('no internet') ||
        str.contains('error during request') ||
        str.contains('clientexception: {url:');
  }

  /// Returns a user-friendly title for the error state.
  static String getTitle(Object? error, {String? defaultTitle}) {
    if (error == null) return defaultTitle ?? 'Unable to Load';

    if (isNetworkError(error)) {
      return 'No Internet Connection';
    }

    final str = error.toString().toLowerCase();

    if (str.contains('statuscode: 401') || str.contains('status: 401') || str.contains('token expired')) {
      return 'Session Expired';
    }

    if (str.contains('statuscode: 403') || str.contains('status: 403')) {
      return 'Access Denied';
    }

    if (str.contains('statuscode: 404') || str.contains('status: 404')) {
      return 'Not Found';
    }

    if (str.contains('statuscode: 500') ||
        str.contains('statuscode: 502') ||
        str.contains('statuscode: 503') ||
        str.contains('status: 500') ||
        str.contains('status: 502') ||
        str.contains('status: 503')) {
      return 'Server Unavailable';
    }

    return defaultTitle ?? 'Something Went Wrong';
  }

  /// Returns a user-friendly explanatory message for full-screen / card error views.
  static String getDescription(Object? error, {String? defaultMessage}) {
    if (error == null) {
      return defaultMessage ?? 'Please check your connection or try again later.';
    }

    if (isNetworkError(error)) {
      return 'Unable to reach Needil servers. Please check your internet connection and try again.';
    }

    final str = error.toString().toLowerCase();

    if (str.contains('statuscode: 401') || str.contains('status: 401')) {
      return 'Your session has expired. Please sign in again to continue.';
    }

    if (str.contains('statuscode: 403') || str.contains('status: 403')) {
      return 'You do not have permission to access this resource.';
    }

    if (str.contains('statuscode: 404') || str.contains('status: 404')) {
      return 'The requested record or resource was not found.';
    }

    if (str.contains('statuscode: 500') ||
        str.contains('statuscode: 502') ||
        str.contains('statuscode: 503')) {
      return 'Our servers are experiencing temporary issues. Please try again in a few moments.';
    }

    if (str.contains('clientexception:')) {
      final clean = _extractCleanMessage(error.toString());
      if (clean != null && clean.isNotEmpty) return clean;
      return 'A server error occurred. Please try again.';
    }

    return defaultMessage ?? format(error);
  }

  /// Sanitizes raw exceptions, hiding internal backend details like PocketBase ClientExceptions,
  /// and returning a user-friendly message for toasts, snacks, and alerts.
  static String format(Object? error) {
    if (error == null) return 'An error occurred';
    final str = error.toString();
    final lower = str.toLowerCase();

    if (isNetworkError(error)) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (lower.contains('statuscode: 400') || lower.contains('status: 400')) {
      final clean = _extractCleanMessage(str);
      if (clean != null && clean.isNotEmpty) return clean;
      return 'Invalid request parameter or query error.';
    }

    if (lower.contains('statuscode: 401') || lower.contains('status: 401')) {
      return 'Session expired. Please sign in again.';
    }

    if (lower.contains('statuscode: 403') || lower.contains('status: 403')) {
      return 'Access denied. You do not have permission for this resource.';
    }

    if (lower.contains('statuscode: 404') || lower.contains('status: 404')) {
      return 'Resource not found.';
    }

    if (lower.contains('statuscode: 500') ||
        lower.contains('statuscode: 502') ||
        lower.contains('statuscode: 503')) {
      return 'Server is temporarily unavailable. Please try again shortly.';
    }

    if (lower.contains('clientexception:')) {
      final clean = _extractCleanMessage(str);
      if (clean != null && clean.isNotEmpty) return clean;
      return 'A server error occurred. Please try again later.';
    }

    if (str.startsWith('Exception: ')) {
      return str.substring('Exception: '.length).trim();
    }

    return str;
  }

  /// Extracts readable messages from PB response JSON string if possible.
  static String? _extractCleanMessage(String raw) {
    try {
      final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(raw);
      if (match != null && match.group(1) != null) {
        final msg = match.group(1)!.trim();
        if (msg.isNotEmpty && !msg.toLowerCase().contains('failed to fetch') && !msg.toLowerCase().contains('clientexception')) {
          return msg;
        }
      }
    } catch (_) {}
    return null;
  }
}
