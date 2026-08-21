import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/voyager_disclaimer.dart';
import '../l10n/voyager_strings.dart';
import '../theme/voyager_theme.dart';

/// The safety and liability notice, shown before Voyager is first used.
///
/// Two properties are deliberate. It is not dismissible by tapping outside or
/// by the back button: consent to a liability notice that can be swiped away
/// is not consent. And declining closes the app rather than continuing in a
/// reduced mode — there is no version of a navigation app that is safe to use
/// by someone who has refused to accept that it might be wrong.
class DisclaimerDialog extends StatelessWidget {
  const DisclaimerDialog({super.key});

  /// Returns true when accepted. Never returns false: a decline closes the app
  /// from inside the dialog.
  static Future<bool> show(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DisclaimerDialog(),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    // The notice follows the device locale, not Voyager's own two-language UI:
    // the chrome being English for a Greek user is an inconvenience, a
    // liability notice being English for them is not something they can
    // meaningfully accept.
    final body = VoyagerDisclaimer.forLanguage(
      Localizations.localeOf(context).languageCode,
    );

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: VoyagerColors.surface,
        title: Row(
          children: [
            const Icon(
              Icons.gpp_maybe_rounded,
              color: VoyagerColors.warning,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(s.disclaimerTitle)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              body,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: VoyagerColors.textSecondary,
              ),
            ),
          ),
        ),
        // Stacked and full width rather than side by side.
        //
        // The accept label is a sentence, not a word, and it is a sentence in
        // whatever language the device is set to — "Ich habe es gelesen und
        // akzeptiere es" is more than twice the width of the Italian. Two
        // buttons sharing a dialog's width clipped it; giving each its own row
        // means no translation can overflow, and it puts the accept button
        // under the thumb rather than in a corner.
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                s.disclaimerAccept,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: Text(
                s.disclaimerDecline,
                textAlign: TextAlign.center,
                style: const TextStyle(color: VoyagerColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
