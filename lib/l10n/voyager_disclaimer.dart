import 'disclaimer/disclaimer_bg.dart';
import 'disclaimer/disclaimer_cs.dart';
import 'disclaimer/disclaimer_da.dart';
import 'disclaimer/disclaimer_de.dart';
import 'disclaimer/disclaimer_el.dart';
import 'disclaimer/disclaimer_en.dart';
import 'disclaimer/disclaimer_es.dart';
import 'disclaimer/disclaimer_et.dart';
import 'disclaimer/disclaimer_fi.dart';
import 'disclaimer/disclaimer_fr.dart';
import 'disclaimer/disclaimer_ga.dart';
import 'disclaimer/disclaimer_hr.dart';
import 'disclaimer/disclaimer_hu.dart';
import 'disclaimer/disclaimer_it.dart';
import 'disclaimer/disclaimer_ja.dart';
import 'disclaimer/disclaimer_lt.dart';
import 'disclaimer/disclaimer_lv.dart';
import 'disclaimer/disclaimer_mt.dart';
import 'disclaimer/disclaimer_nl.dart';
import 'disclaimer/disclaimer_pl.dart';
import 'disclaimer/disclaimer_pt.dart';
import 'disclaimer/disclaimer_ro.dart';
import 'disclaimer/disclaimer_ru.dart';
import 'disclaimer/disclaimer_sk.dart';
import 'disclaimer/disclaimer_sl.dart';
import 'disclaimer/disclaimer_sv.dart';
import 'disclaimer/disclaimer_zh.dart';

/// The safety and liability notice shown before Voyager is used for the first
/// time, and again whenever this text changes materially.
///
/// Adapted from Roadstr's disclaimer, which covers navigation, and extended for
/// what Voyager adds: media playback, telephony and speech running while the
/// vehicle is moving.
///
/// Available in all 24 official EU languages plus Japanese, Chinese and
/// Russian. This is a liability notice: a user cannot meaningfully accept
/// obligations written in a language they do not read, so the translations are
/// not a nicety here in the way translated UI labels are.
class VoyagerDisclaimer {
  const VoyagerDisclaimer._();

  /// Hive key recording acceptance. Bump the suffix whenever the text changes
  /// in substance — never for a typo fix, always for a new obligation. Every
  /// translation must be updated in the same change, otherwise some users
  /// would be re-prompted with the old obligations.
  static const String acceptanceKey = 'voyager_disclaimer_v1';

  static const Map<String, String> _byLanguage = {
    'bg': voyagerDisclaimerBg,
    'cs': voyagerDisclaimerCs,
    'da': voyagerDisclaimerDa,
    'de': voyagerDisclaimerDe,
    'el': voyagerDisclaimerEl,
    'en': voyagerDisclaimerEn,
    'es': voyagerDisclaimerEs,
    'et': voyagerDisclaimerEt,
    'fi': voyagerDisclaimerFi,
    'fr': voyagerDisclaimerFr,
    'ga': voyagerDisclaimerGa,
    'hr': voyagerDisclaimerHr,
    'hu': voyagerDisclaimerHu,
    'it': voyagerDisclaimerIt,
    'ja': voyagerDisclaimerJa,
    'lt': voyagerDisclaimerLt,
    'lv': voyagerDisclaimerLv,
    'mt': voyagerDisclaimerMt,
    'nl': voyagerDisclaimerNl,
    'pl': voyagerDisclaimerPl,
    'pt': voyagerDisclaimerPt,
    'ro': voyagerDisclaimerRo,
    'ru': voyagerDisclaimerRu,
    'sk': voyagerDisclaimerSk,
    'sl': voyagerDisclaimerSl,
    'sv': voyagerDisclaimerSv,
    'zh': voyagerDisclaimerZh,
  };

  /// Language codes with a translation, for tests and for the settings screen.
  static Iterable<String> get supportedLanguages => _byLanguage.keys;

  /// The notice in [languageCode], falling back to English.
  ///
  /// Matching is on the language subtag alone: a user with `pt-BR` gets the
  /// Portuguese text rather than English, which is the right trade even though
  /// the wording was written for `pt-PT`.
  static String forLanguage(String languageCode) =>
      _byLanguage[languageCode.toLowerCase()] ?? voyagerDisclaimerEn;

  /// Kept for the two call sites that only distinguish Italian from the rest.
  @Deprecated('Use forLanguage with the resolved locale instead')
  static String forLocale(bool italian) =>
      italian ? voyagerDisclaimerIt : voyagerDisclaimerEn;
}
