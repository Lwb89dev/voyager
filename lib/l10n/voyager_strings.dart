import 'package:flutter/widgets.dart';

/// Voyager's own user-facing strings, in English and Italian.
///
/// Roadstr uses generated ARB localisations across 27 languages; Voyager does
/// not yet, and pretending otherwise by shipping 27 machine-translated files
/// would be worse than being honest about two. The shape here — one getter per
/// string, both languages on the same line — is deliberately mechanical so the
/// migration to ARB is a transcription rather than a redesign.
///
/// Roadstr's own screens (the map, its settings) keep using Roadstr's
/// AppLocalizations and stay fully localised; only Voyager's chrome is limited
/// to these two languages.
class VoyagerStrings {
  /// True when the resolved locale is Italian. Every other locale, including
  /// unsupported ones, falls back to English.
  final bool it;

  const VoyagerStrings({required this.it});

  static VoyagerStrings of(BuildContext context) => VoyagerStrings(
        it: Localizations.localeOf(context).languageCode == 'it',
      );

  String _(String en, String italian) => it ? italian : en;

  // ── App identity ────────────────────────────────────────────────────────
  String get appName => 'Voyager';
  String get retry => _('Retry', 'Riprova');
  String get tagline =>
      _('Your car, your rules.', 'La tua auto, le tue regole.');

  // ── Onboarding: welcome ─────────────────────────────────────────────────
  String get welcomeTitle => _('Welcome to Voyager', 'Benvenuto in Voyager');
  String get welcomeBody => _(
        'An in-car dashboard that answers to you and to nobody else. No account, no telemetry, no cloud you did not choose yourself.',
        "Un cruscotto per l'auto che risponde a te e a nessun altro. Nessun account, nessuna telemetria, nessun cloud che non hai scelto tu.",
      );
  String get featureNavTitle => _('Navigation', 'Navigazione');
  String get featureNavBody => _(
        'Roadstr under the hood: OpenStreetMap maps, OSRM routing and community road alerts over Nostr.',
        'Roadstr sotto il cofano: mappe OpenStreetMap, routing OSRM e segnalazioni stradali dalla community via Nostr.',
      );
  String get featureMusicTitle => _('Your music', 'La tua musica');
  String get featureMusicBody => _(
        'Streams from your own Navidrome or Jellyfin server, or plays files already on the device. No subscription anywhere.',
        'Riproduce dal tuo server Navidrome o Jellyfin, oppure i file già sul dispositivo. Nessun abbonamento, da nessuna parte.',
      );
  String get featureVoiceTitle => _('Offline voice', 'Voce offline');
  String get featureVoiceBody => _(
        'Kokoro neural speech runs on the device itself. Directions are spoken without a single byte leaving the car.',
        'La voce neurale Kokoro gira sul dispositivo. Le indicazioni vengono lette senza che un solo byte esca dall\'auto.',
      );
  String get featureWeatherTitle => _('Weather', 'Meteo');
  String get featureWeatherBody => _(
        'Open-Meteo, keyless and free, queried with coordinates rounded so nobody learns where you are heading.',
        'Open-Meteo, gratuito e senza chiave, interrogato con coordinate arrotondate perché nessuno sappia dove stai andando.',
      );
  String get featurePhoneTitle =>
      _('Calls and messages', 'Chiamate e messaggi');
  String get featurePhoneBody => _(
        'Incoming calls and texts appear as large, glanceable cards you can answer without hunting for the phone.',
        'Chiamate e SMS in arrivo compaiono come schede grandi e leggibili a colpo d\'occhio, senza cercare il telefono.',
      );

  // ── Onboarding: permissions ─────────────────────────────────────────────
  String get permsTitle => _('What Voyager needs', 'Cosa serve a Voyager');
  String get permsBody => _(
        'Each of these is requested only when the feature that needs it is switched on. Deny any of them and the rest of the app carries on working.',
        'Ognuno di questi viene richiesto solo quando accendi la funzione che lo usa. Se ne rifiuti uno, il resto dell\'app continua a funzionare.',
      );
  String get permLocation => _('Location', 'Posizione');
  String get permLocationWhy => _(
        'Required for navigation and for local weather. Voyager reads it through Android\'s own location service — the Google Play Services location library is stripped out of the build.',
        'Serve per la navigazione e per il meteo locale. Voyager la legge dal servizio di posizione di Android: la libreria di localizzazione di Google Play Services è rimossa dalla build.',
      );
  String get permNotifications => _('Notifications', 'Notifiche');
  String get permNotificationsWhy => _(
        'Turn-by-turn guidance and playback controls continue while the screen is off or another app is in front.',
        'Le indicazioni passo-passo e i controlli di riproduzione continuano a schermo spento o con un\'altra app in primo piano.',
      );
  String get permPhone => _('Phone and messages', 'Telefono e messaggi');
  String get permPhoneWhy => _(
        'Optional. Lets Voyager show who is calling and read a text aloud instead of you picking up the phone. Nothing is stored and nothing is sent anywhere.',
        'Facoltativo. Permette a Voyager di mostrare chi sta chiamando e leggere un SMS ad alta voce invece di farti prendere il telefono. Niente viene salvato né inviato.',
      );
  String get permGrant => _('Grant', 'Concedi');
  String get permGranted => _('Granted', 'Concesso');
  String get permOpenSettings => _('Open settings', 'Apri le impostazioni');
  String get permBlocked => _(
        'Android will not ask again — this one has to be switched on in the system settings.',
        'Android non lo chiederà più: va attivato dalle impostazioni di sistema.',
      );

  // ── Onboarding: music setup ─────────────────────────────────────────────
  String get musicSetupTitle =>
      _('Where is your music?', 'Dov\'è la tua musica?');
  String get musicSetupBody => _(
        'Point Voyager at a music server you run yourself, or skip this and play what is already on the device. You can change it later in Settings.',
        'Indica a Voyager un server musicale che gestisci tu, oppure salta e riproduci quello che è già sul dispositivo. Puoi cambiarlo dopo nelle Impostazioni.',
      );
  // ── Onboarding: voice setup ──────────────────────────────────────────────
  String get voiceSetupTitle => _('Give it a voice', 'Dagli una voce');
  String get voiceSetupBody => _(
        'Both are optional and both can be downloaded later from Settings — skip either one now if you would rather do it on Wi-Fi.',
        'Sono entrambi facoltativi e scaricabili in seguito dalle Impostazioni — salta pure se preferisci farlo con il Wi-Fi.',
      );

  String get useLocalFiles =>
      _('Use files on this device', 'Usa i file su questo dispositivo');
  String get chooseMusicFolder =>
      _('Choose your music folder', 'Scegli la cartella della musica');
  String get useThisFolder => _('Use this folder', 'Usa questa');
  String get folderAdded => _('Added', 'Aggiunta');
  String folderCount(int count) => _('$count folders', '$count cartelle');
  String get musicFolder => _('Music folder', 'Cartella musica');
  String get folderNotChosen => _('Not chosen', 'Non scelta');
  String get folderUnreadable => _(
        'That folder cannot be read. Pick another, or grant access in the system settings.',
        'Questa cartella non è leggibile. Scegline un\'altra, o concedi l\'accesso nelle impostazioni di sistema.',
      );
  String get folderNoSubfolders =>
      _('No sub-folders here', 'Nessuna sottocartella qui');
  String get storageAccessWhy => _(
        'Voyager needs access to the audio on this device before it can list your folders. It reads music files and nothing else.',
        'Voyager ha bisogno di accedere ai file audio del dispositivo prima di poter elencare le cartelle. Legge solo file musicali, nient\'altro.',
      );

  // ── Onboarding: ready ───────────────────────────────────────────────────
  String get readyTitle => _('Ready to drive', 'Pronto a partire');
  String get readyBody => _(
        'Mount the device where you can see it without turning your head, then set off. Voyager will not ask you for anything else.',
        'Fissa il dispositivo dove puoi vederlo senza girare la testa, poi parti. Voyager non ti chiederà altro.',
      );
  String get letsGo => _('Let\'s go', 'Partiamo');
  String get next => _('Next', 'Avanti');
  String get skip => _('Skip', 'Salta');

  // ── Safety disclaimer ───────────────────────────────────────────────────
  String get disclaimerTitle => _('Important notice', 'Avviso importante');
  String get disclaimerAccept =>
      _('I have read and accept', 'Ho letto e accetto');
  String get disclaimerDecline => _('Close the app', 'Chiudi l\'app');

  // ── Settings ────────────────────────────────────────────────────────────
  String get settings => _('Settings', 'Impostazioni');
  String get sectionMusic => _('MUSIC', 'MUSICA');
  String get sectionVoice => _('VOICE', 'VOCE');
  String get sectionMapTheme => _('MAP THEME', 'TEMA MAPPA');
  String get mapTheme => _('Theme', 'Tema');
  String get autoDark => _('Automatic dark theme', 'Tema scuro automatico');
  String get autoDarkWhy => _(
        'Switches the map to the dark variant of your theme between sunset and sunrise, computed on the device from your position.',
        'Passa alla variante scura del tuo tema tra tramonto e alba, calcolato sul dispositivo dalla tua posizione.',
      );
  String get imperialUnits => _('Imperial units', 'Unità imperiali');
  String get imperialUnitsWhy => _(
        'Miles, mph and °F instead of kilometres, km/h and °C — for navigation and weather alike. The same setting Roadstr itself uses.',
        'Miglia, mph e °F al posto di chilometri, km/h e °C — per la navigazione e per il meteo. La stessa impostazione usata da Roadstr.',
      );
  String get sectionDisplay => _('DISPLAY', 'SCHERMO');
  String get sectionPhone => _('PHONE', 'TELEFONO');
  String get sectionInfo => _('INFO', 'INFO');

  String get musicBackend => _('Music source', 'Sorgente musicale');
  String get backendNone => _('Device files only', 'Solo file del dispositivo');
  String get backendNavidrome => 'Navidrome';
  String get backendJellyfin => 'Jellyfin';
  String get serverAddress => _('Server address', 'Indirizzo del server');
  String get username => _('Username', 'Nome utente');
  String get password => _('Password', 'Password');
  String get apiKey => _('API key', 'Chiave API');
  String get userId => _('User ID', 'ID utente');
  String get testConnection => _('Test connection', 'Prova la connessione');
  String get connectionOk => _('Connected', 'Connesso');
  String connectionFailed(String reason) =>
      _('Connection failed: $reason', 'Connessione fallita: $reason');
  String get save => _('Save', 'Salva');
  String get cancel => _('Cancel', 'Annulla');

  String get podcasts => _('Podcasts', 'Podcast');
  String get noSubscriptions => _(
        'No podcasts yet. Add one by name, or paste a feed URL.',
        'Nessun podcast. Aggiungine uno per nome, o incolla l\'URL di un feed.',
      );
  String get addPodcast => _('Add a podcast', 'Aggiungi un podcast');
  String get searchOrFeedUrl =>
      _('Search, or paste a feed URL', 'Cerca, o incolla l\'URL di un feed');
  String get searchAction => _('Search', 'Cerca');
  String get add => _('Add', 'Aggiungi');
  String get unsubscribe => _('Unsubscribe', 'Disiscriviti');
  String get noEpisodes => _('No episodes', 'Nessun episodio');
  String feedFailed(String reason) => _(
        'Could not read the feed: $reason',
        'Impossibile leggere il feed: $reason',
      );
  String get browseLibrary => _('Library', 'Libreria');
  String get artists => _('Artists', 'Artisti');
  String get albums => _('Albums', 'Album');
  String get songs => _('Songs', 'Brani');
  String get libraryEmpty => _('Nothing here', 'Niente qui');
  String get playSomething => _('Play something', 'Metti qualcosa');
  String get equalizer => _('Equalizer', 'Equalizzatore');
  String get off => _('Off', 'Spento');
  String get equalizerEnabled => _('Equalizer on', 'Equalizzatore attivo');
  String get equalizerEnabledWhy => _(
        'Adjusts the output before it reaches the stereo. Off means the audio is passed through untouched.',
        'Regola l\'uscita prima che arrivi allo stereo. Spento, l\'audio passa inalterato.',
      );
  String get equalizerUnavailable => _(
        'This device does not expose an equalizer, or it is not ready yet. Start playing something and come back.',
        'Questo dispositivo non espone un equalizzatore, o non è ancora pronto. Avvia la riproduzione e torna qui.',
      );

  /// Preset names. Kept as a lookup rather than a getter per preset so adding
  /// one upstream does not silently render as a raw enum name.
  String presetName(String preset) {
    switch (preset) {
      case 'flat':
        return _('Flat', 'Neutro');
      case 'roadNoise':
        return _('Road noise', 'Rumore di strada');
      case 'speech':
        return _('Speech', 'Parlato');
      case 'boost':
        return _('Boost', 'Boost');
      case 'rock':
        return _('Rock', 'Rock');
      case 'pop':
        return _('Pop', 'Pop');
      case 'jazz':
        return _('Jazz', 'Jazz');
      case 'metal':
        return _('Metal', 'Metal');
      case 'rap':
        return _('Hip-Hop / Rap', 'Hip-Hop / Rap');
      case 'custom':
        return _('Custom', 'Personalizzato');
      default:
        return preset;
    }
  }

  String get spokenGuidance => _('Spoken guidance', 'Indicazioni vocali');
  String get spokenGuidanceWhy => _(
        'Kokoro when a voice model is installed, eSpeak-NG otherwise.',
        'Kokoro quando è installato un modello vocale, altrimenti eSpeak-NG.',
      );
  String get voiceCommands => _('Voice commands', 'Comandi vocali');
  String get voiceCommandsWhy => _(
        'Requires a Vosk speech model. Without one, Voyager speaks but does not listen.',
        'Richiede un modello vocale Vosk. Senza, Voyager parla ma non ascolta.',
      );
  String get notInstalled => _('Not installed', 'Non installato');

  String get voiceModelDownload => _('Download', 'Scarica');
  String get voiceModelDownloading => _('Downloading…', 'Download in corso…');
  String get voiceModelReady => _('Installed', 'Installato');
  String get voiceModelRetry => _('Retry', 'Riprova');
  String voiceModelError(String message) =>
      _('Download failed: $message', 'Download non riuscito: $message');
  String get voiceModelSkip => _(
        'You can do this later from Settings.',
        'Puoi farlo più avanti dalle Impostazioni.',
      );
  String get kokoroCardTitle =>
      _('Neural voice (Kokoro)', 'Voce neurale (Kokoro)');
  String get kokoroCardBody => _(
        'A natural-sounding voice for turn-by-turn guidance, generated on the device. Without it, Voyager falls back to the robotic eSpeak-NG.',
        'Una voce naturale per le indicazioni di guida, generata sul dispositivo. Senza, Voyager usa la voce robotica eSpeak-NG.',
      );
  String get kokoroVoiceGender => _('Voice', 'Voce');
  String get kokoroVoiceFemale => _('Female', 'Femminile');
  String get kokoroVoiceMale => _('Male', 'Maschile');
  String get kokoroVoiceSpeed => _('Speed', 'Velocità');
  String get voskCardTitle =>
      _('Voice commands (Vosk)', 'Comandi vocali (Vosk)');
  String get voskCardBody => _(
        'Downloads the offline speech model. Recognition itself is still in development — see the changelog — so Voyager will not yet act on what it hears.',
        'Scarica il modello vocale offline. Il riconoscimento vero e proprio è ancora in sviluppo — vedi il changelog — quindi Voyager non agisce ancora su quello che sente.',
      );
  String get voskUnsupportedLanguage => _(
        'No small Vosk model for this language yet.',
        'Nessun modello Vosk compatto per questa lingua, per ora.',
      );

  String get lightTheme => _('Light theme', 'Tema chiaro');
  String get lightThemeWhy => _(
        'Only this settings screen — parked-use administration, not the driving dashboard. The map, music and podcast panes always stay dark.',
        'Solo questa schermata — è amministrazione da usare a veicolo fermo, non il cruscotto di guida. Mappa, musica e podcast restano sempre scuri.',
      );
  String get keepScreenOn => _('Keep the screen on', 'Tieni lo schermo acceso');
  String get keepScreenOnWhy => _(
        'The screen never sleeps while Voyager is in front. Leave this on when the device is powered from the car.',
        'Lo schermo non si spegne mentre Voyager è in primo piano. Lascialo attivo quando il dispositivo è alimentato dall\'auto.',
      );
  String get nightDimming => _('Dim at night', 'Riduci luminosità di notte');
  String get nightDimmingWhy => _(
        'Drops the brightness after sunset, computed on the device from your position — no network call.',
        'Abbassa la luminosità dopo il tramonto, calcolato sul dispositivo dalla tua posizione: nessuna chiamata di rete.',
      );

  String get wheelControls =>
      _('Steering wheel controls', 'Comandi al volante');
  String get wheelControlsWhy => _(
        'Map the volume rocker on the wheel to previous/next track. Volume itself stays with the car stereo.',
        'Assegna il bilanciere del volume al volante a brano precedente/successivo. Il volume resta allo stereo dell\'auto.',
      );

  String get showCallerId =>
      _('Show incoming calls', 'Mostra chiamate in arrivo');
  String get readMessagesAloud =>
      _('Read messages aloud', 'Leggi i messaggi ad alta voce');
  String get readMessagesAloudWhy => _(
        'The sender and the text are spoken once and never stored.',
        'Mittente e testo vengono letti una volta e mai salvati.',
      );

  String get infoVersion => _('Version', 'Versione');
  String get infoNavigation => _('Navigation engine', 'Motore di navigazione');
  String get infoMaps => _('Maps', 'Mappe');
  String get infoWeather => _('Weather', 'Meteo');
  String get infoSpeech => _('Speech', 'Voce');
  String get infoLicence => _('Licence', 'Licenza');
  String get infoSource => _('Source code', 'Codice sorgente');

  String get supportVoyager => _('Support Voyager', 'Sostieni Voyager');
  String lightningCopied(String address) => _(
        'Lightning address copied: $address',
        'Indirizzo Lightning copiato: $address',
      );
}
