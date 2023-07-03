import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:eq_trainer/main.dart';
import 'package:eq_trainer/model/audio_clip.dart';
import 'package:eq_trainer/player/isolated_music_player.dart';

// SessionData - Manage Variables required for Session
class SessionData extends ChangeNotifier {
  int _startingBand = 3;
  int _gain = 6;
  double _qFactor = 1;
  FilterType _filterType = FilterType.peakDip;
  int _threshold = 3;

  int get startingBand => _startingBand;
  set startingBand(int value) {
    _startingBand = value.clamp(2, 25);
    notifyListeners();
  }
  int get gain => _gain;
  set gain(int value) {
    _gain = value;
    notifyListeners();
  }
  double get qFactor => _qFactor;
  set qFactor(double value) {
    _qFactor = value;
    notifyListeners();
  }
  FilterType get filterType => _filterType;
  set filterType(FilterType value) {
    _filterType = value;
    notifyListeners();
  }
  int get threshold => _threshold;
  set threshold(int value) {
    _threshold = value;
    notifyListeners();
  }
}

// SessionAudioData - Manage Playlist of Audio Clips required for Session
class SessionAudioData extends ChangeNotifier {
  int currentPlayingAudioIndex = 0;
  List<String> audioClipPathList = [];

  // Load Audio Clip files from Hive Database
  void updateAudioClipPathList() {
    final audioClipBox = Hive.box<AudioClip>(audioClipBoxName);
    audioClipPathList = [];
    if(audioClipBox.isEmpty) return;

    audioClipBox.values.where((element) => element.isEnabled)
        .forEach((element) => audioClipPathList.add("${audioClipDir.path}/${element.fileName}"));
  }
}

// SessionFrequencyData - Manage Audio Frequency Data required for Session
class SessionFrequencyData extends ChangeNotifier {
  // List of Center Frequencies of Each Graph in Log Scale (for Filter)
  List<double> centerFreqLogList = [];
  // List of Center Frequencies of Each Graph in Linear Scale (for UI)
  List<double> centerFreqLinearList = [];
  // List of Graph Bar Data
  List<LineChartBarData> graphBarDataList = [];

  final graphStateNotifier = ValueNotifier<GraphState>(GraphState.loading);

  // --- initSessionFreqData Function ---
  // Collective Function for Initializing Frequency Data for Session.
  Future<void> initSessionFreqData() async {
    graphStateNotifier.value = GraphState.loading;

    // == Find Center Frequencies of Each Graphs (with LOGARITHMIC Scale for Filter) ==
    // * Center Frequencies in LOGARITHMIC Scale = applied to Audio Filter
    //
    // Originally Frequency Graph has Logarithmic Scale.
    // Let's say Every Graph's Center Frequency are evenly distributed from 20hz to 20kHz (20000hz).
    // If we think Multiplier m = 1000^(1 / (2 * # of Center Frequencies)), then...
    // Center Frequency C(i + 1) equals(=) m^2 * C(i), and C(0) equals(=) 20 * m , while 0 <= i < '# of Center Frequency'.
    // Think about Space-Around Alignment in Flutter or CSS, but in Logarithmic Horizon Scale. :) Got it?
    centerFreqLogList.clear();
    num multiplier = pow(1000, 1 / (2 * mainSessionData.startingBand));
    double centerFreqLog = 20 * multiplier.toDouble();
    for(int i = 0; i < mainSessionData.startingBand; ++i) {
      centerFreqLogList.add(centerFreqLog);
      centerFreqLog *= pow(multiplier, 2);
    }

    // == Find Center Frequencies of Each Graphs (with LINEAR Scale for Filter) ==
    // * Center Frequencies in LINEAR Scale = applied to Graph UI
    //
    // The Gaussian Graph that is shown to User does not follow Logarithmic Scale (just like OG Harman How to Listen)
    // For Aesthetic Reason, I believe. Let's say our graph is 0 to 200 in Horizon Scale.
    centerFreqLinearList.clear();
    num adder = 100 / mainSessionData.startingBand;
    double centerFreqLinear = adder.toDouble();
    for(int i = 0; i < mainSessionData.startingBand; ++i) {
      centerFreqLinearList.add(centerFreqLinear);
      centerFreqLinear += (2 * adder);
    }

    // == Calculate Spots as UI Graph (Gaussian Function) ==
    // https://en.wikipedia.org/wiki/Gaussian_function
    //
    // a : height of Gaussian Graph
    // b : center frequency of graph
    // c : standard deviation of Graph
    // e : exponential of Gaussian Function
    // h : calculated result of Gaussian Function = height of graph
    //
    // There's no specific c value, I just chose what looks great on this app.
    double a = 2;
    double b;
    double c = (16 - (mainSessionData.startingBand / 2)).toDouble();
    double e;
    double h;
    graphBarDataList.clear();

    for(int i = 0; i < mainSessionData.startingBand; ++i) {
      b = centerFreqLinearList[i];
      List<FlSpot> peakGraphSpotList = [];
      List<FlSpot> dipGraphSpotList = [];

      // if Filter Type includes Peak Filter
      if(mainSessionData.filterType != FilterType.dip) {
        for(int j = 0; j <= 200; ++j) {
          e = (0 - ((pow((j - b), 2) / (2 * pow(c, 2)))));
          h = a * exp(e);
          peakGraphSpotList.add(FlSpot(j.toDouble(), h));
        }
        graphBarDataList.add(
            LineChartBarData(
              isCurved: true,
              color: Colors.redAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              spots: peakGraphSpotList,
            )
        );
      }

      // if Filter Type includes Dip Filter
      if(mainSessionData.filterType != FilterType.peak) {
        for(int j = 0; j <= 200; ++j) {
          e = (0 - ((pow((j - b), 2) / (2 * pow(c, 2)))));
          h = 0 - a * exp(e);
          dipGraphSpotList.add(FlSpot(j.toDouble(), h));
        }
        graphBarDataList.add(
            LineChartBarData(
              isCurved: true,
              color: Colors.redAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
              spots: dipGraphSpotList,
            )
        );
      }
    }
    graphBarDataList[0] = graphBarDataList[0].copyWith(color: Colors.blueAccent);

    // Reset Number Picker Value
    currentPickerValue = 1;
    previousPickerValue = 1;

    // Notify Graph data is ready
    graphStateNotifier.value = GraphState.ready;
  }

  // Random Answer for Session Round - in Graph Index
  late int sessionResultGraphIndex;
  // Random Answer for Session Round - in Center Frequency
  late int sessionResultFreqIndex;
  // center frequency applied to EQ
  late double sessionResultCenterFreq;

  // Collective Function for initializing Session.
  Future<void> initSession(BuildContext context) async {
    final player = Provider.of<IsolatedMusicPlayer>(context, listen: false);

    // Num of Graph
    int numOfGraph = graphBarDataList.length;

    // Select Random Index of Graph
    // = Correct Answer for Session
    final random = Random();
    sessionResultGraphIndex = random.nextInt(numOfGraph);
    if(mainSessionData.filterType == FilterType.peakDip) sessionResultFreqIndex = (sessionResultGraphIndex / 2).floor();
    sessionResultCenterFreq = centerFreqLogList[sessionResultFreqIndex];
    player.setEQCenterFreq(sessionResultCenterFreq);

    // Determine Appropriate Gain Value
    // if chosen graph is dip graph, invert gain value of session.
    if(mainSessionData.filterType == FilterType.dip || (mainSessionData.filterType == FilterType.peakDip && sessionResultGraphIndex % 2 == 1)) {
      player.setEQGain(0 - mainSessionData.gain);
    }
    else {
      player.setEQGain(mainSessionData.gain);
    }
    notifyListeners();
  }

  void swapGraphColor(int prevIdx, int currIdx) {
    graphBarDataList[prevIdx] = graphBarDataList[prevIdx].copyWith(color: Colors.redAccent);
    graphBarDataList[currIdx] = graphBarDataList[currIdx].copyWith(color: Colors.blueAccent);
    notifyListeners();
  }

  // Number Picker values for session Number Picker Slider
  int currentPickerValue = 1;
  int previousPickerValue = 1;
}

// SessionResultData - Manage results of each session
class SessionResultData extends ChangeNotifier {
  // Variables for recording Result of Each Session
  int elapsedSession = 0;
  List<int> elapsedSessionPerFreq = [0, 0, 0, 0, 0, 0, 0];
  int resultCorrect = 0;
  List<int> correctAnswerPerFreq = [0, 0, 0, 0, 0, 0, 0];
  int resultIncorrect = 0;

  // Reset Session Result
  void resetResult() {
    elapsedSession = 0;
    elapsedSessionPerFreq = [0, 0, 0, 0, 0, 0, 0];
    resultCorrect = 0;
    correctAnswerPerFreq = [0, 0, 0, 0, 0, 0, 0];
    resultIncorrect = 0;

    notifyListeners();
  }

  // Get each session's center frequency, and record each result
  void updateResultFromFreq(double centerFreq, bool isCorrect) {
    int resultIndex = 0;
    // Sub-Bass - 20 ~ 80
    if(20 <= centerFreq && centerFreq < 80) { resultIndex = 0; }
    // Mid-Bass :: 80 ~ 200
    else if(80 <= centerFreq && centerFreq < 200) { resultIndex = 1; }
    // Lower-Midrange :: 200 ~ 800
    else if(200 <= centerFreq && centerFreq < 800) { resultIndex = 2; }
    // Centre-Midrange :: 800 ~ 1.5k
    else if(800 <= centerFreq && centerFreq < 1500) { resultIndex = 3; }
    // Upper-Midrange :: 1.5k ~ 5k
    else if(1500 <= centerFreq && centerFreq < 5000) { resultIndex = 4; }
    // Treble :: 5k ~ 10k
    else if(5000 <= centerFreq && centerFreq < 10000) { resultIndex = 5; }
    // Upper-Treble :: 10k ~ 20k
    else { resultIndex = 6; }

    elapsedSession++;
    elapsedSessionPerFreq[resultIndex]++;

    if(!isCorrect) {
      resultIncorrect++;
    } else {
      resultCorrect++;
      correctAnswerPerFreq[resultIndex]++;
    }
    notifyListeners();
  }

  double get resultPercentage => resultCorrect * 100 / elapsedSession;
  String getResultPercentagePerFreq(int index) {
    if(elapsedSessionPerFreq[index] == 0) {
      return "-";
    } else {
      return "${(correctAnswerPerFreq[index] * 100 / elapsedSessionPerFreq[index]).toStringAsFixed(2)}%";
    }
  }

  List<List<String>> titleList = [
    ["RESULT_FREQ_SUB_BASS", "20Hz ~ 80Hz"],
    ["RESULT_FREQ_MID_BASS", "80Hz ~ 200Hz"],
    ["RESULT_FREQ_LOWER_MIDRANGE", "200Hz ~ 800Hz"],
    ["RESULT_FREQ_CENTRE_MIDRANGE", "800Hz ~ 1.5kHz"],
    ["RESULT_FREQ_UPPER_MIDRANGE", "1.5kHz ~ 5kHz"],
    ["RESULT_FREQ_TREBLE", "5kHz ~ 10kHz"],
    ["RESULT_FREQ_UPPER_TREBLE", "10kHz ~ 20kHz"],
  ];
}

// SessionStateData - Used for controlling content to show user
class SessionStateData extends ChangeNotifier {
  SessionState _sessionState = SessionState.loading;
  int _selectedGraphValue = 1;
  int currentSessionPoint = 0;

  SessionState get sessionState => _sessionState;
  set sessionState(SessionState sessionState) {
    _sessionState = sessionState;
    notifyListeners();
  }

  int get selectedGraphValue => _selectedGraphValue;
  set selectedGraphValue(int input) {
    _selectedGraphValue = input;
    notifyListeners();
  }
}

enum GraphState { loading, ready }

enum FilterType { peak, dip, peakDip }

enum SessionState { loading, ready, playlistEmpty }