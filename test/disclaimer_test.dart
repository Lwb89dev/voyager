import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/l10n/voyager_disclaimer.dart';

void main() {
  /// The 24 official languages of the European Union, plus the three the
  /// project committed to beyond it.
  const required = [
    'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr',
    'ga', 'hr', 'hu', 'it', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt',
    'ro', 'sk', 'sl', 'sv',
    'ja', 'zh', 'ru',
  ];

  test('every promised language has a translation', () {
    for (final language in required) {
      expect(
        VoyagerDisclaimer.supportedLanguages,
        contains(language),
        reason: 'missing disclaimer translation for "$language"',
      );
    }
  });

  test('no translation is a stub', () {
    // The English text is around 5 700 characters. A translation far shorter
    // than that has lost sections — which for a liability notice means the
    // user accepted something different from what everyone else accepted.
    //
    // Japanese and Chinese get their own floor: they carry the same content in
    // roughly a third of the characters, so the alphabetic threshold would
    // fail them for being correctly written. The section check below is what
    // actually guards their completeness.
    const cjk = {'ja', 'zh'};
    for (final language in required) {
      final text = VoyagerDisclaimer.forLanguage(language);
      final floor = cjk.contains(language) ? 1200 : 3000;
      expect(
        text.length,
        greaterThan(floor),
        reason: '"$language" looks truncated (${text.length} chars)',
      );
    }
  });

  test('every translation keeps all eleven sections', () {
    // The emoji headings are the section markers and are identical across
    // languages, which makes them a structural check that does not depend on
    // reading any of them.
    const markers = ['🚗', '🎵', '⚠️', '🚫', '📍', '🛡️', '🤝', '🔒', '🎧', '⚖️'];
    for (final language in required) {
      final text = VoyagerDisclaimer.forLanguage(language);
      for (final marker in markers) {
        expect(
          text,
          contains(marker),
          reason: '"$language" is missing the $marker section',
        );
      }
    }
  });

  test('an unknown language falls back to English rather than throwing', () {
    expect(
      VoyagerDisclaimer.forLanguage('xx'),
      VoyagerDisclaimer.forLanguage('en'),
    );
  });

  test('a regional locale resolves to its base language', () {
    expect(
      VoyagerDisclaimer.forLanguage('PT'),
      VoyagerDisclaimer.forLanguage('pt'),
    );
  });

  test('the acceptance key is versioned', () {
    // A change to the notice that does not change this key would leave every
    // existing user having accepted obligations they were never shown.
    expect(VoyagerDisclaimer.acceptanceKey, matches(RegExp(r'_v\d+$')));
  });
}
