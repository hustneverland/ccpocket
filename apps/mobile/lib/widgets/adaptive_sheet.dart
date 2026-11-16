import 'package:material_ui/material_ui.dart';

import '../utils/platform_helper.dart';

/// Widest a desktop settings dialog grows. Wider windows keep this width so
/// option lists stay scannable.
const double kDesktopSheetDialogMaxWidth = 480;

/// Margin kept between a desktop settings dialog and the window edges.
const double kDesktopSheetDialogMargin = 24;

/// Shows [builder] as a bottom sheet on mobile and macOS/Linux, and as a
/// bounded, centered dialog on Windows.
///
/// Windows windows are wide, so a full-width bottom sheet puts the options far
/// from the pointer. The same content builder is reused in both presentations;
/// callers close it with `Navigator.pop` on the context they are given, as
/// they would a sheet.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  if (!isWindowsPlatform) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(kDesktopSheetDialogMargin),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: kDesktopSheetDialogMaxWidth,
        ),
        // Fill the allowed width so every settings dialog is the same size,
        // whatever its content measures.
        child: SizedBox(
          width: double.infinity,
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}
