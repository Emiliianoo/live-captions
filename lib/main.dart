import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'caption_screen.dart';

void main() {
  // Needed before talking to the system (the line below) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  // Full screen: hide the status and navigation bars. A swipe from the edge
  // shows them for a moment.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const LiveCaptionsApp());
}

class LiveCaptionsApp extends StatelessWidget {
  const LiveCaptionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subtítulos en vivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CaptionScreen(),
    );
  }
}
