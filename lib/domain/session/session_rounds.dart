import 'dart:math';

import 'package:eq_trainer/domain/session/band_layout.dart';
import 'package:eq_trainer/domain/session/session_results.dart';
import 'package:eq_trainer/domain/session/session_settings.dart';

/// One question: which graph is the one being applied to the audio.
class Round {
  const Round({
    required this.answerGraphIndex,
    required this.frequency,
    required this.gainDb,
  });

  /// 0-based, in the session's current [BandLayout].
  final int answerGraphIndex;

  /// Centre of the answer's band in Hz.
  final double frequency;

  /// Signed: negative when the answer is a dip.
  final double gainDb;
}

/// What answering a round did.
class RoundOutcome {
  const RoundOutcome({
    required this.isCorrect,
    required this.correctGraphIndex,
    required this.bandCountChanged,
    required this.next,
  });

  final bool isCorrect;

  /// The answer of the round that was just answered, in the layout it was
  /// asked in.
  final int correctGraphIndex;

  /// Whether the band ladder moved, which makes [SessionRounds.layout] a new
  /// layout and [next] a graph of it.
  final bool bandCountChanged;

  /// The round that follows.
  final Round next;
}

/// The rules of a training session, without the audio or the screen.
///
/// It picks each round's answer, scores the user's pick, and moves the band
/// count up and down the band ladder. The band count is the session's own: it
/// starts at [SessionSettings.startingBand] and the settings are never
/// written to, so the next session starts where the user configured it.
class SessionRounds {
  SessionRounds(this.settings, {Random? random})
      : _random = random ?? Random(),
        _layout = BandLayout(settings.startingBand, settings.filterType) {
    _current = _pick();
  }

  final SessionSettings settings;
  final Random _random;

  BandLayout _layout;
  late Round _current;
  int _points = 0;
  int _previousGraph = -1;
  SessionResults _results = SessionResults.empty();

  BandLayout get layout => _layout;
  int get bandCount => _layout.bandCount;

  /// The running score: +1 for a correct answer, -1 for a wrong one, back to
  /// 0 whenever the band count changes.
  int get points => _points;

  SessionResults get results => _results;
  Round get current => _current;

  /// Scores [pickedGraphIndex] against the current round and moves to the next.
  RoundOutcome submit(int pickedGraphIndex) {
    assert(pickedGraphIndex >= 0 && pickedGraphIndex < _layout.graphCount);
    final answered = _current;
    final isCorrect = pickedGraphIndex == answered.answerGraphIndex;

    _results = _results.withRound(
      ResultBand.of(answered.frequency),
      isCorrect: isCorrect,
    );
    _points += isCorrect ? 1 : -1;
    final bandCountChanged = _climbLadder();

    _current = _pick();
    return RoundOutcome(
      isCorrect: isCorrect,
      correctGraphIndex: answered.answerGraphIndex,
      bandCountChanged: bandCountChanged,
      next: _current,
    );
  }

  /// Moves the band count when the points reach the threshold either way.
  ///
  /// Uses >= and <= rather than == so a score that already overshot still
  /// fires. At either end of the ladder the points are clamped to the
  /// threshold instead of piling up, which would otherwise take the whole
  /// overshoot to claw back before the band count could move the other way.
  bool _climbLadder() {
    final threshold = settings.threshold;
    int? newBandCount;

    if (_points >= threshold) {
      if (bandCount < SessionSettings.maxBands) {
        newBandCount = bandCount + 1;
      } else {
        _points = threshold;
      }
    } else if (_points <= -threshold) {
      if (bandCount > SessionSettings.minBands) {
        newBandCount = bandCount - 1;
      } else {
        _points = -threshold;
      }
    }

    if (newBandCount == null) return false;
    _layout = BandLayout(newBandCount, settings.filterType);
    _points = 0;
    // The graphs change size and meaning, so a stale index from the old layout
    // must not suppress a legitimate repeat, or sit outside the new range.
    _previousGraph = -1;
    return true;
  }

  Round _pick() {
    final graphCount = _layout.graphCount;
    // With only 2 graphs, forbidding a repeat forces a strict 1,2,1,2,...
    // alternation that can be solved without listening. Only forbid a repeat
    // when there is a real choice.
    int graph;
    do {
      graph = _random.nextInt(graphCount);
    } while (graphCount > 2 && graph == _previousGraph);
    _previousGraph = graph;

    return Round(
      answerGraphIndex: graph,
      frequency: _layout.frequencyOf(graph),
      gainDb: _layout.signedGain(graph, settings.gain.toDouble()),
    );
  }
}
