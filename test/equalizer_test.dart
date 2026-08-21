import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/plugins/music/equalizer_controller.dart';

void main() {
  group('preset resampling', () {
    test('keeps the anchors when the band count matches', () {
      final shape = EqualizerPreset.roadNoise.shape(5);
      expect(shape, [0.75, 0.5, 0.0, 0.1, 0.2]);
    });

    test('interpolates onto a device with more bands', () {
      // A ten-band equalizer must get the same *curve*, not the same numbers
      // crammed into the first five slots.
      final shape = EqualizerPreset.roadNoise.shape(10);
      expect(shape, hasLength(10));
      expect(shape.first, closeTo(0.75, 0.001));
      expect(shape.last, closeTo(0.2, 0.001));
    });

    test('interpolates onto a device with fewer bands', () {
      final shape = EqualizerPreset.boost.shape(3);
      expect(shape, hasLength(3));
      expect(shape.first, closeTo(0.6, 0.001));
      expect(shape.last, closeTo(0.55, 0.001));
    });

    test('copes with a single-band equalizer', () {
      expect(EqualizerPreset.speech.shape(1), hasLength(1));
    });

    test('returns nothing for a device reporting no bands', () {
      expect(EqualizerPreset.flat.shape(0), isEmpty);
    });

    test('flat is silent in both directions', () {
      expect(EqualizerPreset.flat.shape(5).every((g) => g == 0.0), isTrue);
    });

    test('every preset stays inside the normalised range', () {
      // Shapes are fractions of the device's own gain range; a value outside
      // -1..1 would be clamped later and silently change the curve's shape.
      for (final preset in EqualizerPreset.values) {
        for (final gain in preset.shape(7)) {
          expect(gain, inInclusiveRange(-1.0, 1.0), reason: preset.name);
        }
      }
    });

    test('road noise lifts the bottom and leaves the middle alone', () {
      // The point of the preset: at speed, road and wind noise mask the low
      // end almost completely, and nothing else needs touching.
      final shape = EqualizerPreset.roadNoise.shape(5);
      expect(shape.first, greaterThan(0.5));
      expect(shape[2], 0.0);
    });

    test('speech cuts bass and lifts presence', () {
      final shape = EqualizerPreset.speech.shape(5);
      expect(shape.first, lessThan(0));
      expect(shape[3], greaterThan(0));
    });

    test('rock and pop scoop opposite ends of the spectrum', () {
      // Rock: lifted bass and treble, recessed mids. Pop: forward mids for
      // vocals, recessed treble. Same underlying (Winamp-derived) data, near
      // opposite shapes.
      final rock = EqualizerPreset.rock.shape(5);
      final pop = EqualizerPreset.pop.shape(5);
      expect(rock.first, greaterThan(0));
      expect(rock[4], greaterThan(0));
      expect(rock[1], lessThan(0));
      expect(pop[1], greaterThan(0));
      expect(pop[4], lessThan(0));
    });

    test('metal scoops the low-mids and lifts bass, presence and treble', () {
      final shape = EqualizerPreset.metal.shape(5);
      expect(shape.first, greaterThan(0));
      expect(shape[1], lessThan(0));
      expect(shape[3], greaterThan(0));
      expect(shape[4], greaterThan(0));
    });

    test('rap leads with sub-bass and a presence lift for vocals', () {
      final shape = EqualizerPreset.rap.shape(5);
      expect(shape.first, greaterThan(shape[1]));
      expect(shape.first, greaterThan(0.4));
      expect(shape[3], greaterThan(0));
    });
  });

  group('resample', () {
    test('preserves both endpoints exactly', () {
      final out = EqualizerPreset.resample([0.0, 1.0], 5);
      expect(out.first, 0.0);
      expect(out.last, 1.0);
    });

    test('produces a straight line between two anchors', () {
      final out = EqualizerPreset.resample([0.0, 1.0], 3);
      expect(out[1], closeTo(0.5, 0.001));
    });
  });
}
