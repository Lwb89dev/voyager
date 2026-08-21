# Automotive UX guidelines

The rule everything else follows from: **a glance away from the road should
last under two seconds, and a task should need no more than three of them.**
That is NHTSA's driver-distraction guidance, and it is the reason for every
number in `AutomotiveConfig`.

## Touch targets

Minimum 80 dp square (`AutomotiveConfig.minTouchTargetDp`), which is roughly
12 mm on a typical dashboard-mounted screen. A driver aims with a thumb from
memory, on a moving surface, without looking; anything smaller is a target that
gets missed and then hunted for.

Two deliberate exceptions:

- The music overlay's transport controls are 56 dp. Full size would double the
  strip's height and hide a meaningful slice of the map, and the same three
  controls exist at full size one button-bar tap away — and on the wheel, where
  they need no target at all.
- The call answer/reject buttons are 96 dp, the largest in the app, and placed
  as far apart as the row allows. They are pressed under time pressure without
  looking, and they are the one pair where the wrong choice cannot be undone.

## Typography

Minimum 16 sp for anything at all; 20 sp for secondary text; 28 sp for the one
thing on screen that matters most. Sunlight and arm's length, not a desk.

Truncate rather than wrap. A wrapped line changes the layout underneath it,
and layout that moves has to be re-read.

## Colour

Dark ground, one saturated hue. `VoyagerColors` is sampled from the app icon:
near-black `#02040F` with violet `#812DF8`. A bright screen reflects onto the
windscreen at night, so Voyager ships no light theme — there is no ambient
condition in which a bright dashboard is the better choice.

Because violet is the only saturated colour, anything that must catch the eye
(an active route, an incoming call, a hazard) is the only saturated thing on
screen. Spend that budget carefully.

Night dimming paints a scrim over the whole app, including the button bar,
after local sunset — computed on-device from the position, no light sensor and
no network call.

## Motion

Transitions are capped at 180 ms. Anything longer forces a second glance to see
where the UI ended up.

No animation runs while it is not visible — the voice plugin's pulsing
indicator stops its controller when hidden, because a ticking animation wakes
the raster thread on every frame the map is trying to use.

No fade on album art. It is movement in peripheral vision carrying no
information.

## Interaction

**Physical controls beat the touchscreen.** The wheel rocker skips tracks; the
assistant key starts listening; the menu key returns to the map. Every one of
those actions also exists on screen, but the physical path is the one the
design assumes while moving.

**No gesture triggers anything consequential.** There is deliberately no
swipe-to-expand on the music overlay: a panel that grows over live navigation
because the car hit a pothole is exactly the failure this rules out.

**One-tap "play something".** Selecting music by browsing is a parked activity.
The shuffle button is the only music interaction the UI encourages in motion.

**No dialler, no contact list, no message history.** Choosing a name from a
list of hundreds is not a two-second glance.

## Information

Show one number, not a table. The weather pane shows a temperature, a
condition and a wind figure, and skips the hourly strip entirely — a driver
does not plan a week from the dashboard, and the extra rows would shrink the
figures that matter.

Say why something failed. "Music server unreachable" stops the tapping;
a spinner that never resolves does not.

## Speech

Spoken output is prioritised: a manoeuvre instruction may cut an ambient alert,
but never another instruction. A weather hazard is announced once per condition
change, never on a timer — a voice that repeats itself for two hours gets tuned
out, and then it is not a warning.

Speech recognition is held to a higher bar than it usually is. Commands below
0.6 confidence are downgraded to "not understood" rather than executed, because
a false positive means the car doing something the driver never asked for.

## Manual test checklist

Things no unit test covers:

- [ ] Map pan and zoom hold 60 fps with music playing.
- [ ] Track changes are gapless across an album.
- [ ] Wheel rocker skips tracks with the screen off.
- [ ] A call arriving during guidance shows the card and pauses music.
- [ ] Guidance is audible over music at motorway speed.
- [ ] Night dimming engages after local sunset.
- [ ] Every pane is legible in direct sunlight.
- [ ] Losing Wi-Fi mid-drive degrades to local files without stopping playback.
