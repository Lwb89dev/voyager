import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:roadstr/l10n/app_localizations.dart';
import 'package:roadstr/theme/app_theme.dart';
import 'package:roadstr/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/automotive_config.dart';
import '../l10n/voyager_strings.dart';
import '../plugins/music/jellyfin_client.dart';
import '../plugins/music/music_folder_service.dart';
import '../plugins/music/navidrome_client.dart';
import '../plugins/music/equalizer_controller.dart';
import '../plugins/music/music_plugin.dart';
import '../services/automotive_gesture_service.dart';
import '../services/automotive_ui_service.dart';
import '../services/open_source_config.dart';
import '../services/plugin_service.dart';
import '../theme/voyager_theme.dart';
import 'equalizer_screen.dart';
import 'music_folder_screen.dart';
import '../widgets/voyager_scope.dart';

enum MusicBackend { navidrome, jellyfin }

/// Settings, arranged the way Roadstr's are: sections of plain rows, each
/// setting explained in a sentence underneath rather than in a help screen
/// nobody opens.
///
/// This screen is explicitly not automotive-sized. It is meant to be used
/// parked, so it uses ordinary controls at ordinary sizes and fits far more on
/// screen than the dashboard would allow.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _box = Hive.box('settings');
  String _version = '0.1.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    // Read from the package rather than hard-coding it: a version string that
    // is maintained in two places is a version string that is wrong in one.
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    final config = OpenSourceConfig.load();
    final ui = context.watch<AutomotiveUiService>();
    final gestures = context.read<AutomotiveGestureService>();

    return VoyagerScope(
      child: Scaffold(
        backgroundColor: VoyagerColors.background,
        appBar: AppBar(title: Text(s.settings)),
        // A Scaffold's body sees the system's insets untouched except for what
        // its own AppBar already consumed — a display cutout on a long edge in
        // landscape is left for the body to handle itself. Without this, the
        // cutout on this screen's own left edge fell across the first column
        // of every row's icon rather than the margin next to it.
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _SectionHeader(s.sectionMusic),
              _NavigationRow(
                icon: Icons.dns_rounded,
                title: s.backendNavidrome,
                value: config.hasNavidrome
                    ? config.navidromeEndpoint!
                    : s.backendNone,
                onTap: () => _openServer(MusicBackend.navidrome),
              ),
              _NavigationRow(
                icon: Icons.movie_filter_rounded,
                title: s.backendJellyfin,
                value: config.hasJellyfin
                    ? config.jellyfinEndpoint!
                    : s.backendNone,
                onTap: () => _openServer(MusicBackend.jellyfin),
              ),
              _NavigationRow(
                icon: Icons.sd_storage_rounded,
                title: s.musicFolder,
                value: MusicFolderService.chosenFolder ?? s.folderNotChosen,
                onTap: _openFolderPicker,
              ),
              _NavigationRow(
                icon: Icons.graphic_eq_rounded,
                title: s.equalizer,
                value: _equalizerSummary(s),
                onTap: _openEqualizer,
              ),
              const SizedBox(height: AutomotiveConfig.sectionGap),
              _SectionHeader(s.sectionVoice),
              _InfoRow(
                title: s.spokenGuidance,
                value: config.hasKokoro ? 'Kokoro' : 'eSpeak-NG',
                subtitle: s.spokenGuidanceWhy,
              ),
              _InfoRow(
                title: s.voiceCommands,
                value: config.hasVosk ? 'Vosk' : s.notInstalled,
                subtitle: s.voiceCommandsWhy,
              ),
              const SizedBox(height: AutomotiveConfig.sectionGap),
              _SectionHeader(s.sectionMapTheme),
              _MapThemeRow(s: s),
              _SwitchRow(
                title: s.autoDark,
                subtitle: s.autoDarkWhy,
                value: context.watch<ThemeProvider>().autoDarkEnabled,
                onChanged: context.read<ThemeProvider>().setAutoDarkEnabled,
              ),
              const SizedBox(height: AutomotiveConfig.sectionGap),
              _SectionHeader(s.sectionDisplay),
              _SwitchRow(
                title: s.keepScreenOn,
                subtitle: s.keepScreenOnWhy,
                value: ui.keepAwake,
                onChanged: ui.setKeepAwake,
              ),
              _SwitchRow(
                title: s.nightDimming,
                subtitle: s.nightDimmingWhy,
                value: ui.nightDimming,
                onChanged: (value) {
                  ui.setNightDimming(value);
                  _box.put('voyager_night_dimming', value);
                },
              ),
              _SwitchRow(
                title: s.wheelControls,
                subtitle: s.wheelControlsWhy,
                value: gestures.remapVolumeKeys,
                onChanged: (value) => setState(() {
                  gestures.remapVolumeKeys = value;
                  _box.put('voyager_remap_volume', value);
                }),
              ),
              const SizedBox(height: AutomotiveConfig.sectionGap),
              _SectionHeader(s.sectionPrivacy),
              _InfoRow(
                title: s.telemetry,
                value: s.telemetryValue,
                subtitle: s.privacyBody,
              ),
              const SizedBox(height: AutomotiveConfig.sectionGap),
              _SectionHeader(s.sectionInfo),
              _InfoRow(title: s.infoVersion, value: _version),
              _InfoRow(title: s.infoNavigation, value: 'Roadstr · OSRM'),
              _InfoRow(
                title: s.infoMaps,
                value: 'openstreetmap.org',
                url: 'https://www.openstreetmap.org',
              ),
              _InfoRow(
                title: s.infoWeather,
                value: 'open-meteo.com',
                url: 'https://open-meteo.com',
              ),
              _InfoRow(title: s.infoSpeech, value: 'Kokoro · eSpeak-NG'),
              _InfoRow(title: s.infoLicence, value: 'GPL v3'),
              _InfoRow(
                title: s.infoSource,
                value: 'github.com/Lwb89dev/voyager',
                url: 'https://github.com/Lwb89dev/voyager',
              ),
              const SizedBox(height: AutomotiveConfig.gutter),
              const DonationTile(),
            ],
          ),
        ),
      ),
    );
  }

  /// Null when the music plugin never came up — no server, no library, no
  /// audio session, and therefore no equalizer to configure.
  EqualizerController? get _equalizer {
    final music = context.read<PluginService>().byId('music');
    return music is MusicPlugin ? music.equalizer : null;
  }

  String _equalizerSummary(VoyagerStrings s) {
    final equalizer = _equalizer;
    if (equalizer == null || !equalizer.isReady) return s.notInstalled;
    // Not backendNone: that reads "device files only", which is a music-source
    // answer and says nothing about an equalizer.
    if (!equalizer.isEnabled) return s.off;
    return s.presetName(equalizer.presetName);
  }

  Future<void> _openEqualizer() async {
    final equalizer = _equalizer;
    if (equalizer == null) return;
    await EqualizerScreen.show(context, equalizer);
    if (mounted) setState(() {});
  }

  Future<void> _openFolderPicker() async {
    await MusicFolderScreen.show(context);
    if (mounted) setState(() {});
  }

  Future<void> _openServer(MusicBackend backend) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MusicServerScreen(backend: backend),
    ));
    // The config is read fresh on every build, so a save on the other screen
    // shows up as soon as this one rebuilds.
    if (mounted) setState(() {});
  }
}

/// Lightning donations.
///
/// Copied in behaviour from Roadstr's own tile, address included: Voyager is
/// built on Roadstr and the support goes to the same place. Tapping tries the
/// `lightning:` handler first so a wallet on the device opens straight into a
/// payment, and falls back to the clipboard when nothing handles the scheme —
/// which is what happens on most devices, so the fallback is the common path,
/// not the edge case.
class DonationTile extends StatelessWidget {
  static const String lightningAddress = 'lwb89@blink.sv';

  const DonationTile({super.key});

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return GestureDetector(
      onTap: () => _donate(context, s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: VoyagerColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: VoyagerColors.accent.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              color: VoyagerColors.accentLight,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.supportVoyager,
                    style: const TextStyle(
                      color: VoyagerColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    lightningAddress,
                    style: TextStyle(
                      color: VoyagerColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              size: 15,
              color: VoyagerColors.accentLight,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _donate(BuildContext context, VoyagerStrings s) async {
    final messenger = ScaffoldMessenger.of(context);
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse('lightning:$lightningAddress'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (launched) return;
    await Clipboard.setData(const ClipboardData(text: lightningAddress));
    messenger.showSnackBar(
      SnackBar(content: Text(s.lightningCopied(lightningAddress))),
    );
  }
}

// ── Music server form ──────────────────────────────────────────────────────

/// Credentials for one music backend, with a connection test.
///
/// The test button is not decoration. A wrong port or a typo'd password
/// otherwise surfaces as an empty library at the next traffic light, with no
/// indication of which of the four fields is wrong.
class MusicServerScreen extends StatefulWidget {
  final MusicBackend backend;

  const MusicServerScreen({super.key, required this.backend});

  @override
  State<MusicServerScreen> createState() => _MusicServerScreenState();
}

class _MusicServerScreenState extends State<MusicServerScreen> {
  late final OpenSourceConfig _config = OpenSourceConfig.load();
  late final TextEditingController _endpoint;
  late final TextEditingController _first;
  late final TextEditingController _second;

  String? _result;
  bool _testing = false;
  bool _ok = false;

  bool get _isNavidrome => widget.backend == MusicBackend.navidrome;

  @override
  void initState() {
    super.initState();
    _endpoint = TextEditingController(
      text: _isNavidrome ? _config.navidromeEndpoint : _config.jellyfinEndpoint,
    );
    _first = TextEditingController(
      text: _isNavidrome ? _config.navidromeUsername : _config.jellyfinApiKey,
    );
    _second = TextEditingController(
      text: _isNavidrome ? _config.navidromePassword : _config.jellyfinUserId,
    );
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final s = VoyagerStrings.of(context);
    try {
      await _probe();
      setState(() {
        _ok = true;
        _result = s.connectionOk;
      });
    } catch (error) {
      setState(() {
        _ok = false;
        _result = s.connectionFailed(_describe(error));
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _probe() {
    if (_isNavidrome) {
      return NavidromeClient(
        endpoint: _endpoint.text.trim(),
        username: _first.text.trim(),
        password: _second.text,
      ).ping();
    }
    return JellyfinClient(
      endpoint: _endpoint.text.trim(),
      apiKey: _first.text.trim(),
      userId: _second.text.trim(),
    ).ping();
  }

  Future<void> _save() async {
    final endpoint = _endpoint.text.trim();
    final updated = _isNavidrome
        ? _config.copyWith(
            navidromeEndpoint: endpoint,
            navidromeUsername: _first.text.trim(),
            navidromePassword: _second.text,
          )
        : _config.copyWith(
            jellyfinEndpoint: endpoint,
            jellyfinApiKey: _first.text.trim(),
            jellyfinUserId: _second.text.trim(),
          );
    await updated.save();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);
    return VoyagerScope(
      child: Scaffold(
        backgroundColor: VoyagerColors.background,
        appBar: AppBar(
          title: Text(_isNavidrome ? s.backendNavidrome : s.backendJellyfin),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Field(
              controller: _endpoint,
              label: s.serverAddress,
              hint: _isNavidrome
                  ? 'http://192.168.1.100:4533'
                  : 'http://192.168.1.100:8096',
              keyboardType: TextInputType.url,
            ),
            _Field(
              controller: _first,
              label: _isNavidrome ? s.username : s.apiKey,
            ),
            _Field(
              controller: _second,
              label: _isNavidrome ? s.password : s.userId,
              obscure: _isNavidrome,
            ),
            const SizedBox(height: 20),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  _result!,
                  style: TextStyle(
                    color: _ok ? VoyagerColors.success : VoyagerColors.danger,
                    fontSize: 14,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _testing ? null : _test,
                    child: Text(_testing ? '…' : s.testConnection),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: _save, child: Text(s.save)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _describe(Object error) {
    final text = error.toString();
    final colon = text.indexOf(': ');
    return colon < 0 ? text : text.substring(colon + 2);
  }
}

/// The map's theme, offered as Roadstr offers it.
///
/// Voyager's own chrome stays dark whatever is chosen here — a bright panel in
/// a windscreen mount reflects onto the glass, and that reasoning does not
/// change with a preference. The map is a different case: it is the thing being
/// looked at rather than furniture around it, Roadstr ships eight themes for
/// it, and which one suits a given car and a given time of day is not
/// Voyager's call to make.
///
/// The labels come from Roadstr's own localisations, so they read correctly in
/// all 27 languages it supports rather than only the two Voyager's own strings
/// cover.
class _MapThemeRow extends StatelessWidget {
  final VoyagerStrings s;

  const _MapThemeRow({required this.s});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final l = AppLocalizations.of(context);

    return _Row(
      child: Row(
        children: [
          const Icon(
            Icons.palette_rounded,
            color: VoyagerColors.accentLight,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s.mapTheme,
              style: const TextStyle(
                color: VoyagerColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<AppThemeId>(
              value: provider.current,
              onChanged: (id) {
                if (id != null) context.read<ThemeProvider>().setTheme(id);
              },
              dropdownColor: VoyagerColors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              style: const TextStyle(
                color: VoyagerColors.textPrimary,
                fontSize: 13,
              ),
              items: [
                for (final id in AppThemeId.values)
                  DropdownMenuItem(
                    value: id,
                    child: Text(id.localizedLabel(l)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: Text(
          title,
          style: const TextStyle(
            color: VoyagerColors.accentLight,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Row({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: VoyagerColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? url;

  const _InfoRow({
    required this.title,
    required this.value,
    this.subtitle,
    this.url,
  });

  @override
  Widget build(BuildContext context) => _Row(
        onTap: url == null
            ? null
            : () => launchUrl(
                  Uri.parse(url!),
                  mode: LaunchMode.externalApplication,
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: VoyagerColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: url == null
                        ? VoyagerColors.textSecondary
                        : VoyagerColors.accentLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: VoyagerColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
}

class _NavigationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _NavigationRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _Row(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: VoyagerColors.accentLight, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: VoyagerColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VoyagerColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: VoyagerColors.textSecondary,
            ),
          ],
        ),
      );
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => _Row(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: VoyagerColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: VoyagerColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(color: VoyagerColors.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: VoyagerColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}
