/// What the navigation plugin is doing, from Voyager's point of view.
///
/// Roadstr owns the real routing state internally; this is the coarse summary
/// the dashboard needs in order to decide things like whether to collapse the
/// music overlay for an upcoming manoeuvre.
enum NavigationStatus {
  /// Map is up, no route set.
  idle,

  /// A route is being computed.
  routing,

  /// Actively guiding.
  guiding,

  /// GPS was lost while guiding. Distinct from [idle] because guidance is
  /// still armed and will resume on its own.
  signalLost,
}

class NavigationState {
  final NavigationStatus status;

  /// Next manoeuvre text, as Roadstr phrased it. Null when not guiding.
  final String? nextInstruction;

  /// Metres to the next manoeuvre, or null when unknown.
  final int? distanceToManoeuvre;

  const NavigationState({
    required this.status,
    this.nextInstruction,
    this.distanceToManoeuvre,
  });

  const NavigationState.idle()
      : status = NavigationStatus.idle,
        nextInstruction = null,
        distanceToManoeuvre = null;

  bool get isGuiding => status == NavigationStatus.guiding;

  /// True when a manoeuvre is close enough that the driver's attention belongs
  /// entirely on the road. The dashboard collapses the music overlay and
  /// suppresses non-urgent notifications while this holds.
  ///
  /// 300 m is roughly ten seconds at motorway speed — long enough to finish
  /// whatever is on screen, short enough that nothing new appears during the
  /// manoeuvre itself.
  bool get manoeuvreImminent {
    final distance = distanceToManoeuvre;
    return isGuiding && distance != null && distance <= 300;
  }
}
