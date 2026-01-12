
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/user_provider.dart';
import '../../services/podcast_service.dart';
import '../../data/models/civics_question_model.dart';
import 'dart:convert';

// Global Handler Access (Simple approach for this scope)
PodcastService? _audioHandler;

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  bool _isLoading = true;
  double _speed = 1.0;
  bool _isShuffle = false;
  
  // Colors
  final Color navyBlue = const Color(0xFF1A237E);
  final Color federalBlue = const Color(0xFF112D50);
  final Color teal = const Color(0xFF00C4B4);

  @override
  void initState() {
    super.initState();
    _initAudioService();
  }

  String? _errorMessage;

  Future<void> _initAudioService() async {
    try {
      if (_audioHandler == null) {
        _audioHandler = await AudioService.init(
          builder: () => PodcastService(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.citizen128.channel.audio',
            androidNotificationChannelName: 'Citizen128 Podcast',
            androidNotificationIcon: 'mipmap/ic_launcher',
          ),
        );
        
        // Load Questions
        if (mounted) {
           final userProvider = Provider.of<UserProvider>(context, listen: false);
           final version = userProvider.studyVersion;
           final file = version == '2008' ? 'assets/civics_questions_2008.json' : 'assets/civics_questions_2025.json';
           
           final String jsonString = await DefaultAssetBundle.of(context).loadString(file);
           final List<dynamic> jsonList = jsonDecode(jsonString);
           final questions = jsonList.map((j) => CivicsQuestion.fromJson(j)).toList();
           
           // Prepare Dynamic Data
           Map<String, String> dynamicData = {
             'senator1': userProvider.civicSenator1 ?? "Not Found",
             'senator2': userProvider.civicSenator2 ?? "Not Found",
             'representative': userProvider.civicRepresentative ?? "Not Found",
             'governor': userProvider.civicGovernor ?? "Not Found",
             'capital': userProvider.civicCapital ?? "Not Found",
           };

           await _audioHandler!.init(questions, version, dynamicData);
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading Podcast: $e");
      if (mounted) setState(() {
         _isLoading = false;
         _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) return Scaffold(
       appBar: AppBar(title: const Text("Error")),
       body: Center(child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Text("Failed to load Podcast Mode:\n$_errorMessage", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
       ))
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light Grey
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down, color: federalBlue, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Podcast Mode", style: GoogleFonts.publicSans(color: federalBlue, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<MediaItem?>(
        stream: _audioHandler!.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          final title = mediaItem?.title ?? "Loading...";
          final artist = mediaItem?.artist ?? "Citizen128";
          
          return Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               // Album Art / Visual
               Container(
                 width: 250, height: 250,
                 decoration: BoxDecoration(
                   color: navyBlue,
                   borderRadius: BorderRadius.circular(20),
                   boxShadow: [BoxShadow(color: navyBlue.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                 ),
                 child: Icon(Icons.headphones, color: Colors.white.withOpacity(0.8), size: 100),
               ),
               const SizedBox(height: 40),
               
               // Title
               Text(title, style: GoogleFonts.publicSans(fontSize: 24, fontWeight: FontWeight.bold, color: federalBlue)),
               Text(artist, style: GoogleFonts.publicSans(fontSize: 16, color: Colors.grey)),
               
               const SizedBox(height: 40),
               
               // Controls
               StreamBuilder<PlaybackState>(
                 stream: _audioHandler!.playbackState,
                 builder: (context, snapshot) {
                   final playing = snapshot.data?.playing ?? false;
                   final processingState = snapshot.data?.processingState ?? AudioProcessingState.idle;
                   
                   return Column(
                     children: [
                       // Progress Bar (Mock visual or could bind to index/total if exposed)
                       // LinearProgressIndicator(value: ...), 
                       
                       Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                            // Shuffle
                            IconButton(
                              icon: Icon(Icons.shuffle, color: _isShuffle ? teal : Colors.grey),
                              onPressed: () {
                                setState(() => _isShuffle = !_isShuffle);
                                _audioHandler!.setShuffleMode(_isShuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);
                              },
                              tooltip: "Shuffle",
                            ),
                            
                            // Restart
                             Container(
                               margin: const EdgeInsets.symmetric(horizontal: 8),
                               child: IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.grey),
                                onPressed: () async {
                                  await _audioHandler!.restart();
                                },
                                tooltip: "Start Over",
                              ),
                             ),

                            // Prev
                            IconButton(
                              icon: Icon(Icons.skip_previous_rounded, size: 40, color: federalBlue),
                              onPressed: _audioHandler!.skipToPrevious,
                            ),
                            
                            // Play/Pause
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(color: navyBlue, shape: BoxShape.circle),
                              child: IconButton(
                                icon: Icon(playing ? Icons.pause : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                onPressed: playing ? _audioHandler!.pause : _audioHandler!.play,
                              ),
                            ),
                            
                            // Next
                            IconButton(
                              icon: Icon(Icons.skip_next_rounded, size: 40, color: federalBlue),
                              onPressed: _audioHandler!.skipToNext,
                            ),
                            
                            const SizedBox(width: 20),
                            
                            // Speed
                            TextButton(
                               onPressed: () {
                                  double newSpeed = _speed == 1.0 ? 1.25 : (_speed == 1.25 ? 1.5 : 1.0);
                                  setState(() => _speed = newSpeed);
                                  _audioHandler!.setSpeed(_speed);
                               },
                               child: Text("${_speed}x", style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: federalBlue)),
                            )
                         ],
                       ),
                     ],
                   );
                 }
               )
             ],
          );
        },
      ),
    );
  }
}
