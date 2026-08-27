import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide ErrorFormatter;
import 'package:pms_app/core/utils/error_formatter.dart';
import 'package:pms_app/core/widgets/app_error_view.dart';
import 'package:pms_app/core/theme/app_theme.dart';

void main() {
  group('ErrorFormatter Network & Exception Tests', () {
    test('Correctly identifies exact screenshot ClientException as network error', () {
      const screenshotError = 'ClientException: {url: https://api.needil.com/api/collections/appointments/records?page=1&perPage=100&filter=doctor+%3D+%227s81fouiyz9d3nm%22+%26%26+date+%3D+%222026-08-24%22&sort=time&expand=patient%2Cdoctor&skipTotal=false, isAbort: true, statusCode: 0, response: {}, originalError: ClientException: Failed to fetch, uri=https://api.needil.com/api/collections/appointments/records?page=1&perPage=100&filter=doctor+%3D+%227s81fouiyz9d3nm%22+%26%26+date+%3D+%222026-08-24%22&sort=time&expand=patient%2Cdoctor&skipTotal=false}';

      expect(ErrorFormatter.isNetworkError(screenshotError), isTrue);
      expect(ErrorFormatter.getTitle(screenshotError), equals('No Internet Connection'));
      expect(ErrorFormatter.getDescription(screenshotError), contains('Needil servers'));
      expect(ErrorFormatter.format(screenshotError), equals('No internet connection. Please check your network and try again.'));
    });

    test('Identifies various network and connectivity exception patterns', () {
      expect(ErrorFormatter.isNetworkError('SocketException: OS Error: Connection refused, errno = 111'), isTrue);
      expect(ErrorFormatter.isNetworkError('ClientException: XMLHttpRequest error.'), isTrue);
      expect(ErrorFormatter.isNetworkError('TimeoutException after 0:00:30.000000: Future not completed'), isTrue);
      expect(ErrorFormatter.isNetworkError('HandshakeException: Handshake error in client'), isTrue);
      expect(ErrorFormatter.isNetworkError('Failed host lookup: api.needil.com'), isTrue);
      expect(ErrorFormatter.isNetworkError('net::ERR_INTERNET_DISCONNECTED'), isTrue);
      expect(ErrorFormatter.isNetworkError('Network is unreachable'), isTrue);
      expect(ErrorFormatter.isNetworkError('statusCode: 0'), isTrue);
    });

    test('Correctly formats status code errors', () {
      expect(ErrorFormatter.getTitle('statusCode: 401'), equals('Session Expired'));
      expect(ErrorFormatter.getTitle('statusCode: 403'), equals('Access Denied'));
      expect(ErrorFormatter.getTitle('statusCode: 404'), equals('Not Found'));
      expect(ErrorFormatter.getTitle('statusCode: 500'), equals('Server Unavailable'));

      expect(ErrorFormatter.format('statusCode: 401'), equals('Session expired. Please sign in again.'));
      expect(ErrorFormatter.format('statusCode: 403'), equals('Access denied. You do not have permission for this resource.'));
      expect(ErrorFormatter.format('statusCode: 404'), equals('Resource not found.'));
      expect(ErrorFormatter.format('statusCode: 500'), equals('Server is temporarily unavailable. Please try again shortly.'));
    });

    test('Extracts readable message from PB response JSON when available', () {
      const pbError = 'ClientException: {"message":"Phone number already in use","data":{}}';
      expect(ErrorFormatter.format(pbError), equals('Phone number already in use'));
    });
  });

  group('AppErrorView Widget Tests', () {
    testWidgets('Renders No Internet Connection state with Retry button', (tester) async {
      bool retryPressed = false;
      const screenshotError = 'ClientException: {url: https://api.needil.com/api, originalError: ClientException: Failed to fetch, isAbort: true, statusCode: 0}';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppErrorView(
              error: screenshotError,
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.textContaining('Needil servers'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(retryPressed, isTrue);
    });

    testWidgets('Renders Compact mode without overflow', (tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: AppErrorView(
                error: 'Failed to fetch',
                isCompact: true,
                onRetry: () => retryPressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(retryPressed, isTrue);
    });
  });
}
