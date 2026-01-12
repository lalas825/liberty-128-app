import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../data/models/civics_question_model.dart';

class PodcastService extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  
  List<CivicsQuestion> _questions = [];
  int _currentIndex = 0;
  String _currentVersion = '2025'; // Default to modern
  bool _isPlaying = false;
  
  // User Data for Dynamic Answers
  Map<String, String> _dynamicData = {};

  // Gap Engine Timer
  Timer? _gapTimer;

  static const String PREF_INDEX = 'podcast_last_index';
  static const String PREF_VERSION = 'podcast_last_version';

  PodcastService() {
    _initTTS();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
         // Handle regular completion if needed, though Gap Engine manages flow manually
      }
    });
  }

  void _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true); // Wait for TTS to finish
  }

  Future<void> init(List<CivicsQuestion> questions, String version, Map<String, String> dynamicData) async {
    _questions = questions;
    _currentVersion = version;
    _dynamicData = dynamicData;
    
    // Load persisted state
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getString(PREF_VERSION);
    if (savedVersion == version) {
      _currentIndex = prefs.getInt(PREF_INDEX) ?? 0;
    } else {
      _currentIndex = 0;
    }
    
    // Validate index
    if (_currentIndex >= _questions.length) _currentIndex = 0;
    
    _updateMediaItem();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    // TTS rate is 0.0 to 1.0. 0.5 is normal. 
    // Map 1.0x -> 0.5, 1.5x -> 0.75? 
    // Let's just keep TTS clarity high or scale slightly.
    double ttsRate = 0.5;
    if (speed > 1.0) ttsRate = 0.6; 
    if (speed > 1.4) ttsRate = 0.7;
    await _tts.setSpeechRate(ttsRate);
    
    playbackState.add(playbackState.value.copyWith(
       speed: speed
    ));
  }

  // Add Restart Capability
  Future<void> restart() async {
     await pause();
     _currentIndex = 0;
     _updateMediaItem();
     _saveProgress();
     // auto-play? optional. generally unexpected. let user press play.
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final isShuffle = shuffleMode == AudioServiceShuffleMode.all || shuffleMode == AudioServiceShuffleMode.group;
    if (isShuffle) {
       final currentQ = _questions[_currentIndex];
       _questions.shuffle();
       _currentIndex = _questions.indexOf(currentQ);
    } else {
       final currentQ = _questions[_currentIndex];
       _questions.sort((a,b) {
          // Robust int parsing
          int idA = int.tryParse(a.id) ?? 0;
          int idB = int.tryParse(b.id) ?? 0;
          return idA.compareTo(idB);
       });
       _currentIndex = _questions.indexOf(currentQ);
    }
    _updateMediaItem();
    playbackState.add(playbackState.value.copyWith(
       shuffleMode: shuffleMode
    ));
    // Save shuffle preference? Maybe later.
  }


  @override
  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [MediaControl.pause, MediaControl.skipToNext, MediaControl.skipToPrevious],
      processingState: AudioProcessingState.ready,
    ));
    
    _runGapEngine();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _player.stop();
    _tts.stop();
    _gapTimer?.cancel();
    
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [MediaControl.play, MediaControl.skipToNext, MediaControl.skipToPrevious],
      processingState: AudioProcessingState.ready,
    ));
    _saveProgress();
  }

  @override
  Future<void> skipToNext() async {
    _player.stop();
    _tts.stop();
    _gapTimer?.cancel();
    _advanceIndex(1);
    if (_isPlaying) _runGapEngine();
  }

  @override
  Future<void> skipToPrevious() async {
    _player.stop();
    _tts.stop();
    _gapTimer?.cancel();
    _advanceIndex(-1);
    if (_isPlaying) _runGapEngine();
  }
  
  @override
  Future<void> stop() async {
    await pause();
    await super.stop();
  }

  void _advanceIndex(int delta) {
    _currentIndex += delta;
    if (_currentIndex >= _questions.length) _currentIndex = 0;
    if (_currentIndex < 0) _currentIndex = _questions.length - 1;
    _updateMediaItem();
    _saveProgress();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PREF_INDEX, _currentIndex);
    await prefs.setString(PREF_VERSION, _currentVersion);
  }

  void _updateMediaItem() {
    if (_questions.isEmpty) return;
    final q = _questions[_currentIndex];
    mediaItem.add(MediaItem(
      id: q.id,
      album: "Citizen128 Podcast Mode",
      title: "Question ${q.id}",
      artist: "Civics Prep ($_currentVersion)",
      duration: null, // Unknown/Varies
      artUri: null,
    ));
  }

  // --- THE GAP ENGINE ---
  Future<void> _runGapEngine() async {
    if (!_isPlaying || _questions.isEmpty) return;
    
    final currentQ = _questions[_currentIndex];
    final cleanId = _cleanId(currentQ.id); // Use ID directly
    // Actually ID in JSON is usually like "1", "2".
    // File format: q_2025_1.mp3
    
    final qId = currentQ.id; 

    debugPrint("Podcast: Starting Cycle for Q$qId");

    // 1. Play Question
    try {
      final qPath = 'asset:///assets/audio/questions/q_${_currentVersion}_$qId.mp3';
      await _player.setAudioSource(AudioSource.uri(Uri.parse(qPath)));
      await _player.play();
      await _player.processingStateStream.firstWhere((state) => state == ProcessingState.completed);
    } catch (e) {
      debugPrint("Podcast Error Playing Question Q$qId: $e");
      // Fallback to TTS for Question? Or just skip?
      // Let's TTS the question text if file fails
       await _tts.speak(currentQ.questionText);
    }

    if (!_isPlaying) return;

    // 2. Wait 3 Seconds
    await Future.delayed(const Duration(seconds: 3));
    if (!_isPlaying) return;

    // 3. Play Answer
    bool isDynamic = _isDynamic(_currentVersion, qId);
    
    if (isDynamic) {
       final dynamicText = _getDynamicAnswerText(_currentVersion, qId);
       await _tts.speak(dynamicText);
    } else {
       try {
         final aPath = 'asset:///assets/audio/questions/a_${_currentVersion}_$qId.mp3';
         await _player.setAudioSource(AudioSource.uri(Uri.parse(aPath)));
         await _player.play();
         await _player.processingStateStream.firstWhere((state) => state == ProcessingState.completed);
       } catch (e) {
          debugPrint("Podcast Error Playing Answer Q$qId: $e");
          // Fallback TTS
           await _tts.speak(currentQ.acceptableAnswers.isNotEmpty ? currentQ.acceptableAnswers[0] : "No answer available");
       }
    }

    if (!_isPlaying) return;

    // 4. Wait 2 Seconds
    await Future.delayed(const Duration(seconds: 2));
    if (!_isPlaying) return;

    // 5. Next Question
    _advanceIndex(1);
    _runGapEngine(); // Recursive Loop
  }

  // --- Dynamic Helpers (Duplicated logic from SmartAudioService or simplified) ---
  
  String _cleanId(String id) {
     return id; // Assuming ID in model is already "1", "2" etc.
  }

  bool _isDynamic(String version, String id) {
    if (version == '2008') return ['20', '23', '43', '44'].contains(id);
    if (version == '2025') return ['23', '29', '61', '62'].contains(id);
    return false;
  }

  String _getDynamicAnswerText(String version, String id) {
     // Retrieve from _dynamicData
     // Keys: senator1, senator2, representative, governor, capital
     if (id == '20' || (id == '23' && version=='2025')) { // Senators
        final s1 = _dynamicData['senator1'];
        final s2 = _dynamicData['senator2'];
        if (s1 != null) {
           String text = "The answer is $s1";
           if (s2 != null) text += " and $s2";
           return text;
        }
     }
     // Rep
     if ((id == '23' && version=='2008') || id == '29') {
        final r = _dynamicData['representative'];
        if (r != null) return "The answer is $r";
     }
     // Governor
     if (id == '43' || id == '61') {
        final g = _dynamicData['governor'];
        if (g != null) return "The answer is $g";
     }
     // Capital
     if (id == '44' || id == '62') {
         final c = _dynamicData['capital'];
         if (c != null) return "The answer is $c";
     }
     
     return "Please check your profile for local representative details.";
  }
}
