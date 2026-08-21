// First-launch onboarding for Voyager.
//
// Pages:
//   0 — Welcome: what the app is, and the five things it does
//   1 — Permissions: location and notifications, each with the reason
//   2 — Music: point at a server, or use what is on the device
//   3 — Ready: accept the safety notice and start
//
// Modelled on Roadstr's onboarding, which gets the important part right:
// every permission is explained in terms of the feature that needs it, and
// every one of them can be refused without the app becoming useless.
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../config/automotive_config.dart';
import '../l10n/voyager_disclaimer.dart';
import '../l10n/voyager_strings.dart';
import '../plugins/music/music_folder_service.dart';
import '../services/permission_service.dart';
import '../theme/voyager_theme.dart';
import 'disclaimer_dialog.dart';
import 'music_folder_screen.dart';
import 'settings_screen.dart';
import '../widgets/voyager_scope.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 4;

  final _controller = PageController();
  int _page = 0;

  PermissionState _location = PermissionState.askable;
  PermissionState _notifications = PermissionState.askable;
  PermissionState _telephony = PermissionState.askable;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reads the current state of all three without prompting for any of them.
  ///
  /// Called on entry and again whenever the app returns from the system
  /// settings page, so a permission granted out there is reflected here
  /// without the user having to work out that they must tap the button again.
  Future<void> _refreshPermissions() async {
    final states = await Future.wait([
      PermissionService.locationState(),
      PermissionService.notificationState(),
      PermissionService.telephonyState(),
    ]);
    if (!mounted) return;
    setState(() {
      _location = states[0];
      _notifications = states[1];
      _telephony = states[2];
    });
  }

  /// Requests one permission, or opens the system settings when Android has
  /// stopped showing the dialog. A button that silently does nothing after the
  /// second refusal is the worst possible answer here.
  Future<void> _request(
    PermissionState current,
    Future<PermissionState> Function() request,
    void Function(PermissionState) assign,
  ) async {
    if (current == PermissionState.blocked) {
      await PermissionService.openSettings();
      await _refreshPermissions();
      return;
    }
    final result = await request();
    if (mounted) setState(() => assign(result));
  }

  void _next() => _controller.nextPage(
        duration: AutomotiveConfig.transition,
        curve: Curves.easeOut,
      );

  /// Records acceptance and hands control to the dashboard.
  ///
  /// The disclaimer key is versioned, so a future revision of the text
  /// re-prompts rather than inheriting consent given to a different document.
  Future<void> _acceptAndFinish() async {
    final accepted = await DisclaimerDialog.show(context);
    if (!accepted) return;
    await Hive.box('settings').putAll({
      VoyagerDisclaimer.acceptanceKey: true,
      'voyager_onboarding_done': true,
    });
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final s = VoyagerStrings.of(context);

    return VoyagerScope(
      child: Scaffold(
        backgroundColor: VoyagerColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _ProgressDots(page: _page, count: _pageCount),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    _WelcomePage(s: s, onNext: _next),
                    _PermissionsPage(
                      s: s,
                      location: _location,
                      notifications: _notifications,
                      telephony: _telephony,
                      onRequestLocation: () => _request(
                        _location,
                        PermissionService.requestLocation,
                        (v) => _location = v,
                      ),
                      onRequestNotifications: () => _request(
                        _notifications,
                        PermissionService.requestNotifications,
                        (v) => _notifications = v,
                      ),
                      onRequestTelephony: () => _request(
                        _telephony,
                        PermissionService.requestTelephony,
                        (v) => _telephony = v,
                      ),
                      onNext: _next,
                    ),
                    _MusicPage(s: s, onNext: _next),
                    _ReadyPage(s: s, onStart: _acceptAndFinish),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int page;
  final int count;

  const _ProgressDots({required this.page, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            count,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: page == i ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: page == i ? VoyagerColors.accent : VoyagerColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
}

// ── Page 0: welcome ────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoyagerStrings s;
  final VoidCallback onNext;

  const _WelcomePage({required this.s, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.navigation_rounded, s.featureNavTitle, s.featureNavBody),
      (Icons.music_note_rounded, s.featureMusicTitle, s.featureMusicBody),
      (Icons.record_voice_over_rounded, s.featureVoiceTitle, s.featureVoiceBody),
      (Icons.cloud_rounded, s.featureWeatherTitle, s.featureWeatherBody),
      (Icons.phone_rounded, s.featurePhoneTitle, s.featurePhoneBody),
    ];

    return _Page(
      onNext: onNext,
      nextLabel: s.next,
      children: [
        Center(
          child: Image.asset(
            'assets/icons/icon.png',
            width: 108,
            height: 108,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            s.welcomeTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VoyagerColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          s.welcomeBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: VoyagerColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AutomotiveConfig.sectionGap),
        for (final (icon, title, body) in features)
          _FeatureRow(icon: icon, title: title, body: body),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: VoyagerColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: VoyagerColors.accentLight, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VoyagerColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: const TextStyle(
                      color: VoyagerColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Page 1: permissions ────────────────────────────────────────────────────

class _PermissionsPage extends StatelessWidget {
  final VoyagerStrings s;
  final PermissionState location;
  final PermissionState notifications;
  final PermissionState telephony;
  final VoidCallback onRequestLocation;
  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestTelephony;
  final VoidCallback onNext;

  const _PermissionsPage({
    required this.s,
    required this.location,
    required this.notifications,
    required this.telephony,
    required this.onRequestLocation,
    required this.onRequestNotifications,
    required this.onRequestTelephony,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => _Page(
        onNext: onNext,
        nextLabel: s.next,
        children: [
          _PageTitle(title: s.permsTitle, body: s.permsBody),
          const SizedBox(height: AutomotiveConfig.sectionGap),
          _PermissionCard(
            s: s,
            icon: Icons.location_on_rounded,
            title: s.permLocation,
            body: s.permLocationWhy,
            state: location,
            onGrant: onRequestLocation,
          ),
          _PermissionCard(
            s: s,
            icon: Icons.notifications_rounded,
            title: s.permNotifications,
            body: s.permNotificationsWhy,
            state: notifications,
            onGrant: onRequestNotifications,
          ),
          _PermissionCard(
            s: s,
            icon: Icons.phone_rounded,
            title: s.permPhone,
            body: s.permPhoneWhy,
            state: telephony,
            onGrant: onRequestTelephony,
          ),
        ],
      );
}

class _PermissionCard extends StatelessWidget {
  final VoyagerStrings s;
  final IconData icon;
  final String title;
  final String body;
  final PermissionState state;
  final VoidCallback onGrant;

  const _PermissionCard({
    required this.s,
    required this.icon,
    required this.title,
    required this.body,
    required this.state,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VoyagerColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoyagerColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: VoyagerColors.accentLight, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: VoyagerColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (state == PermissionState.granted)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: VoyagerColors.success,
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: VoyagerColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            ..._action(),
          ],
        ),
      );

  /// Nothing to offer when the permission is already granted, or when the
  /// device simply cannot do it — a button that opens a dialog the system will
  /// never show is worse than no button.
  List<Widget> _action() {
    if (state == PermissionState.granted ||
        state == PermissionState.unavailable) {
      return const [];
    }
    final blocked = state == PermissionState.blocked;
    return [
      if (blocked) ...[
        const SizedBox(height: 8),
        Text(
          s.permBlocked,
          style: const TextStyle(
            color: VoyagerColors.warning,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton(
        onPressed: onGrant,
        style: FilledButton.styleFrom(
          backgroundColor:
              blocked ? VoyagerColors.surfaceRaised : VoyagerColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        ),
        child: Text(blocked ? s.permOpenSettings : s.permGrant),
      ),
    ];
  }
}

// ── Page 2: music ──────────────────────────────────────────────────────────

class _MusicPage extends StatelessWidget {
  final VoyagerStrings s;
  final VoidCallback onNext;

  const _MusicPage({required this.s, required this.onNext});

  @override
  Widget build(BuildContext context) => _Page(
        onNext: onNext,
        nextLabel: s.next,
        children: [
          _PageTitle(title: s.musicSetupTitle, body: s.musicSetupBody),
          const SizedBox(height: AutomotiveConfig.sectionGap),
          _MusicChoice(
            icon: Icons.dns_rounded,
            title: s.backendNavidrome,
            body: 'Subsonic API · GPL v3',
            onTap: () => _configure(context, MusicBackend.navidrome),
          ),
          _MusicChoice(
            icon: Icons.movie_filter_rounded,
            title: s.backendJellyfin,
            body: 'Native REST API · GPL v2',
            onTap: () => _configure(context, MusicBackend.jellyfin),
          ),
          _MusicChoice(
            icon: Icons.sd_storage_rounded,
            title: s.useLocalFiles,
            body: s.backendNone,
            onTap: () => _chooseLocalFolder(context),
          ),
        ],
      );

  /// Local playback needs two things the server backends do not: permission to
  /// read audio, and somewhere to look. Asking for both here — rather than
  /// discovering them missing at the first traffic light — is the whole reason
  /// this page exists.
  Future<void> _chooseLocalFolder(BuildContext context) async {
    final granted = await MusicFolderService.requestAccess();
    if (!context.mounted) return;
    if (granted != PermissionState.granted) {
      // Refused. Carry on rather than blocking the tour: the folder can be set
      // later in Settings, and every other feature is unaffected.
      onNext();
      return;
    }
    await MusicFolderScreen.show(context);
    if (context.mounted) onNext();
  }

  Future<void> _configure(BuildContext context, MusicBackend backend) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MusicServerScreen(backend: backend),
    ));
    if (context.mounted) onNext();
  }
}

class _MusicChoice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _MusicChoice({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: VoyagerColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VoyagerColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: VoyagerColors.accentLight, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: VoyagerColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        color: VoyagerColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: VoyagerColors.textSecondary,
              ),
            ],
          ),
        ),
      );
}

// ── Page 3: ready ──────────────────────────────────────────────────────────

class _ReadyPage extends StatelessWidget {
  final VoyagerStrings s;
  final VoidCallback onStart;

  const _ReadyPage({required this.s, required this.onStart});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: VoyagerColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: VoyagerColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              s.readyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VoyagerColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.readyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VoyagerColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: Text(
                  s.letsGo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Shared page furniture ──────────────────────────────────────────────────

class _Page extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback onNext;
  final String nextLabel;

  const _Page({
    required this.children,
    required this.onNext,
    required this.nextLabel,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onNext,
                child: Text(
                  nextLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _PageTitle extends StatelessWidget {
  final String title;
  final String body;

  const _PageTitle({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: VoyagerColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: VoyagerColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      );
}

/// Whether the feature tour still needs to run — true only on a genuinely
/// first launch.
bool onboardingRequired(Box box) =>
    !(box.get('voyager_onboarding_done', defaultValue: false) as bool);

/// Whether the current disclaimer has been accepted.
///
/// Deliberately separate from [onboardingRequired]: when the notice is revised,
/// an existing user must read and accept the new text, but walking them
/// through the feature tour a second time would train them to click past it.
bool disclaimerRequired(Box box) =>
    !(box.get(VoyagerDisclaimer.acceptanceKey, defaultValue: false) as bool);
