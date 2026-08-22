// Voyager — an automotive dashboard built on Roadstr.
//
// Startup, in order:
//
//   1. WidgetsFlutterBinding, before any platform-channel call.
//   2. Hive, and the AES-encrypted `settings` box. Every provider reads
//      persisted settings before the first frame, so this cannot be deferred.
//   3. Orientation and system-UI configuration: landscape-first, edge to edge.
//   4. Services and plugins are constructed and registered — cheap and
//      synchronous — then initialised concurrently in the background.
//   5. runApp, with the provider tree Roadstr's MapScreen also needs.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:roadstr/l10n/app_localizations.dart';
import 'package:roadstr/providers/locale_provider.dart';
import 'package:roadstr/theme/theme_provider.dart';
import 'package:roadstr/widgets/speedometer_widget.dart';

import 'l10n/voyager_strings.dart';
import 'plugins/music/music_plugin.dart';
import 'plugins/navigation/roadstr_plugin.dart';
import 'plugins/phone/phone_plugin.dart';
import 'plugins/podcast/podcast_plugin.dart';
import 'plugins/voice/voice_plugin.dart';
import 'plugins/weather/weather_plugin.dart';
import 'screens/disclaimer_dialog.dart';
import 'screens/onboarding_screen.dart';
import 'services/automotive_gesture_service.dart';
import 'services/automotive_ui_service.dart';
import 'services/open_source_config.dart';
import 'services/plugin_service.dart';
import 'theme/voyager_theme.dart';
import 'widgets/automotive_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release builds say nothing. Route legs, street names and track titles all
  // pass through debugPrint, and logcat is not a private place.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await Hive.initFlutter();
  try {
    await _openEncryptedSettingsBox();
  } catch (error) {
    debugPrint('[Storage] settings unavailable: $error');
    runApp(const _StorageUnavailableApp());
    return;
  }

  // Landscape first — a device on a dashboard mount is almost always wide —
  // but portrait stays allowed, because plenty of vent mounts are not.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(await _buildApp());
}

Future<Widget> _buildApp() async {
  final box = Hive.box('settings');
  // Roadstr's own default is "classic" — a thick gauge ring that leaves the
  // number itself fairly small. "minimal" (a thin progress ring) gives the
  // digits most of the circle instead, which reads better at the smaller
  // size Voyager's compact nav panel uses. Seeded once, only if the user
  // has never touched the setting themselves — set explicitly, in Roadstr's
  // own settings screen or Voyager's, this is never overwritten.
  if (!box.containsKey(SpeedometerStyle.storageKey)) {
    box.put(SpeedometerStyle.storageKey, SpeedometerStyle.minimal.name);
  }
  // Same seed-once rule for imperial units — 'imperialUnits' is Roadstr's own
  // key (Units.imperial reads it directly), shared rather than duplicated so
  // one toggle, in either app's settings, changes navigation and weather
  // together. Defaults to on only for the one country where a driver reading
  // "22°C" would have to stop and convert it: region, not language, decides
  // this, since plenty of US English speakers exist elsewhere and plenty of
  // people in the US have the device set to a language other than English.
  if (!box.containsKey('imperialUnits')) {
    final region =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    box.put('imperialUnits', region == 'US');
  }
  final config = OpenSourceConfig.load();

  // Roadstr's own providers: MapScreen reads ThemeProvider directly, and both
  // are what keep Roadstr's screens looking and speaking the way they do when
  // run as Roadstr.
  final themeProvider = ThemeProvider();
  await themeProvider.init();
  final localeProvider = LocaleProvider();
  await localeProvider.init();

  final gestures = AutomotiveGestureService()
    ..remapVolumeKeys =
        box.get('voyager_remap_volume', defaultValue: false) as bool
    ..attach();

  final ui = AutomotiveUiService();
  await ui.initialize(
    nightDimming: box.get('voyager_night_dimming', defaultValue: true) as bool,
  );

  final plugins = _registerPlugins(config);
  // Not awaited: the dashboard renders its chrome from manifests, and each
  // pane swaps from a placeholder to real content as its plugin comes up.
  // Awaiting here would hold the first frame behind the slowest backend.
  unawaited(plugins.initializeAll());

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: localeProvider),
      ChangeNotifierProvider.value(value: plugins),
      ChangeNotifierProvider.value(value: ui),
      Provider.value(value: gestures),
    ],
    child: const VoyagerApp(),
  );
}

PluginService _registerPlugins(OpenSourceConfig config) {
  final plugins = PluginService();
  final voice = VoicePlugin(config: config, plugins: plugins);

  plugins
    ..register(RoadstrPlugin())
    ..register(MusicPlugin(config: config))
    ..register(PodcastPlugin())
    ..register(WeatherPlugin())
    ..register(voice)
    ..register(PhonePlugin(voice: voice));
  return plugins;
}

/// Opens the AES-encrypted `settings` box, with the key held in the Android
/// Keystore through FlutterSecureStorage.
///
/// Same box name and same key name as Roadstr, because Roadstr's services read
/// their settings out of it and Voyager runs them in-process.
///
/// Unlike Roadstr, there is no plaintext-to-encrypted migration path: Voyager
/// has its own application id and therefore its own documents directory, so no
/// legacy plaintext box can exist. Failure is fail-closed — the box is never
/// silently opened unencrypted or deleted after a transient Keystore error.
Future<void> _openEncryptedSettingsBox() async {
  const storage = FlutterSecureStorage();
  List<int> key;
  try {
    final stored = await storage.read(key: 'hive_settings_key');
    if (stored != null) {
      key = base64Decode(stored);
    } else {
      key = Hive.generateSecureKey();
      await storage.write(key: 'hive_settings_key', value: base64Encode(key));
    }
  } catch (_) {
    throw StateError(
        'Secure storage is unavailable; settings were not opened.');
  }

  if (key.length != 32) {
    throw StateError('The settings encryption key is invalid.');
  }
  await Hive.openBox('settings', encryptionCipher: HiveAesCipher(key));
}

class VoyagerApp extends StatelessWidget {
  const VoyagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Voyager',
      debugShowCheckedModeBanner: false,
      // Roadstr's theme, not Voyager's — see VoyagerScope for why the root
      // belongs to the dependency and Voyager scopes its own screens instead.
      theme: themeProvider.effectiveThemeData,
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        _FallbackMaterialDelegate(),
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _StartupGate(),
    );
  }
}

/// Decides what the user sees first: the feature tour, the safety notice, or
/// the dashboard.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late bool _needsOnboarding;
  late bool _needsDisclaimer;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('settings');
    _needsOnboarding = onboardingRequired(box);
    _needsDisclaimer = disclaimerRequired(box);
    if (!_needsOnboarding && _needsDisclaimer) {
      // Returning user, revised notice: ask for the notice alone rather than
      // replaying a tour they have already seen.
      WidgetsBinding.instance.addPostFrameCallback((_) => _askDisclaimer());
    }
  }

  Future<void> _askDisclaimer() async {
    final accepted = await DisclaimerDialog.show(context);
    if (!accepted || !mounted) return;
    await Hive.box('settings').put(_disclaimerKey, true);
    setState(() => _needsDisclaimer = false);
  }

  static String get _disclaimerKey => 'voyager_disclaimer_v1';

  @override
  Widget build(BuildContext context) {
    if (_needsOnboarding) {
      return OnboardingScreen(
        onComplete: () => setState(() {
          _needsOnboarding = false;
          _needsDisclaimer = false;
        }),
      );
    }
    return const AutomotiveDashboard();
  }
}

/// Accepts every locale, falling back to English for the ones
/// GlobalMaterialLocalizations does not cover.
///
/// Roadstr needs this because it supports Irish and Maltese, which
/// flutter_localizations does not; selecting one without a fallback crashes
/// any Material widget that asks for localisations. Voyager inherits Roadstr's
/// supported-locale list, so it inherits the problem — and the fix, which is
/// reimplemented here because Roadstr's copy is private to its own main.
class _FallbackMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final effective = GlobalMaterialLocalizations.delegate.isSupported(locale)
        ? locale
        : const Locale('en');
    return GlobalMaterialLocalizations.delegate.load(effective);
  }

  @override
  bool shouldReload(_FallbackMaterialDelegate old) => false;
}

/// Shown when the encrypted settings box could not be opened.
///
/// Deliberately a dead end with no "continue anyway": favourites, parked
/// position and server credentials live in that box, and opening it in
/// plaintext or wiping it after a transient Keystore failure would be worse
/// than not starting.
class _StorageUnavailableApp extends StatelessWidget {
  const _StorageUnavailableApp();

  @override
  Widget build(BuildContext context) {
    const strings = VoyagerStrings(it: false);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: VoyagerTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 56,
                  color: VoyagerColors.warning,
                ),
                const SizedBox(height: 20),
                Text(
                  '${strings.appName}: protected settings are unavailable.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VoyagerColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
