import 'package:flutter_test/flutter_test.dart';
import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';
import 'package:eq_trainer/ui/session/state/session_store.dart';

void main() {
  group('SessionStore', () {
    late SessionStore store;

    setUp(() {
      store = SessionStore();
    });

    // -------------------------------------------------------------------------
    // Layout and picker
    // -------------------------------------------------------------------------
    group('applyLayout', () {
      test('shows one curve per graph of the layout', () {
        store.applyLayout(BandLayout(4, FilterType.peakDip));
        expect(store.graphBarDataList, hasLength(8));
        expect(store.centerFreqLinearList, hasLength(4));
        expect(store.layout, equals(BandLayout(4, FilterType.peakDip)));
      });

      test('puts the picker back on the first graph', () {
        store.applyLayout(BandLayout(4, FilterType.peak));
        store.setPickerValue(3);
        store.applyLayout(BandLayout(5, FilterType.peak));
        expect(store.currentPickerValue, 1);
        expect(store.currentGraphIndex, 0);
      });

      test('notifies even when the picker was already on the first graph', () {
        store.applyLayout(BandLayout(4, FilterType.peak));
        var notifications = 0;
        store.addListener(() => notifications++);
        store.applyLayout(BandLayout(5, FilterType.peak));
        expect(notifications, greaterThan(0));
      });

      test('has no layout to give before one is applied', () {
        expect(() => store.layout, throwsStateError);
      });
    });

    group('picker', () {
      setUp(() => store.applyLayout(BandLayout(3, FilterType.peak)));

      test('counts from 1, and the graph index from 0', () {
        store.setPickerValue(3);
        expect(store.currentPickerValue, 3);
        expect(store.currentGraphIndex, 2);
        expect(SessionStore.graphIndexOf(3), 2);
        expect(SessionStore.pickerValueOf(2), 3);
      });

      test('ignores a value outside the graphs', () {
        store.setPickerValue(4);
        store.setPickerValue(0);
        expect(store.currentPickerValue, 1);
      });

      test('does nothing before any graphs are shown', () {
        final fresh = SessionStore();
        fresh.setPickerValue(2);
        expect(fresh.currentPickerValue, 1);
      });
    });

    group('results', () {
      test('start empty', () {
        expect(store.results.rounds, 0);
      });

      test('hold the latest counts and notify', () {
        var notifications = 0;
        store.addListener(() => notifications++);
        final results = SessionResults.empty()
            .withRound(ResultBand.treble, isCorrect: true);

        store.setResults(results);

        expect(store.results, same(results));
        expect(notifications, 1);
      });
    });
  });
}
