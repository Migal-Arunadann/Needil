class ErrorFormatter {
  /// Sanitizes raw exceptions, hiding internal backend details like PocketBase ClientExceptions,
  /// and returning a user-friendly message.
  static String format(Object error) {
    final str = error.toString();
    final lower = str.toLowerCase();

    if (lower.contains('failed to fetch') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception: {url:') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (lower.contains('clientexception:')) {
      return 'A server error occurred. Please try again later.';
    }

    return str;
  }
}
