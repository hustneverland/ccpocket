import 'package:ccpocket/widgets/adaptive_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pumpHost(WidgetTester tester, {required Widget content}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAdaptiveSheet<void>(
                context: context,
                builder: (_) => content,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('uses a bottom sheet outside Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpHost(tester, content: const Text('content'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('uses a width-bounded dialog on Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpHost(
      tester,
      content: const SizedBox(height: 120, child: Text('content')),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    final dialogSize = tester.getSize(find.byType(Dialog));
    expect(dialogSize.width, kDesktopSheetDialogMaxWidth);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('shrinks inside a narrow Windows window', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpHost(tester, content: const Text('content'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialogSize = tester.getSize(find.byType(Dialog));
    expect(dialogSize.width, 400 - 2 * kDesktopSheetDialogMargin);
  });

  testWidgets('scrolls tall content in a short Windows window', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1000, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpHost(
      tester,
      content: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < 30; i++)
              SizedBox(height: 48, child: Text('row $i')),
          ],
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final dialogSize = tester.getSize(find.byType(Dialog));
    expect(
      dialogSize.height,
      lessThanOrEqualTo(360 - 2 * kDesktopSheetDialogMargin),
    );
  });

  testWidgets('Escape closes the Windows dialog', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await _pumpHost(tester, content: const Text('content'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });
}
