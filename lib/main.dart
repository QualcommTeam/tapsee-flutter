// 📦 패키지 import
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(TapSeeApp(cameras: cameras));
}

class TapSeeApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const TapSeeApp({required this.cameras});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: Color(0xFFFFE14D),
        ),
        home: TapSeeHome(cameras: cameras),
      );
}

class TapSeeHome extends StatefulWidget {
  final List<CameraDescription> cameras;
  const TapSeeHome({required this.cameras});

  @override
  State<TapSeeHome> createState() => _TapSeeHomeState();
}

class _TapSeeHomeState extends State<TapSeeHome> {
  final FlutterTts tts = FlutterTts();
  late CameraController _cameraController;
  String message = "";
  double speechRate = 0.5;
  int tapCount = 0;
  Offset dragStart = Offset.zero;
  bool isSpeedSetting = true;
  bool isCameraMode = false;
  bool analysisComplete = false;
  bool isSpeaking = false;
  bool isRepeatingTts = false;
  bool speedSetCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _speak("TapSee를 시작합니다");
      _startSpeedSetting();
    });
  }

  void _initTts() {
    tts.setSpeechRate(speechRate);
    tts.awaitSpeakCompletion(true);
  }

  Future _speak(String text) async {
    await tts.stop();
    setState(() => isSpeaking = true);
    await tts.setSpeechRate(speechRate);
    await tts.speak(text);
    setState(() => isSpeaking = false);
  }

  Future _initializeCamera() async {
    _cameraController = CameraController(
        widget.cameras.first, ResolutionPreset.medium,
        enableAudio: false);
    await _cameraController.initialize();
    if (mounted) setState(() {});
  }

  void _startSpeedSetting() async {
    setState(() {
      isSpeedSetting = true;
      message =
          "음성 속도를 조절합니다. 위로 드래그할수록 빠르게, 아래로 드래그할수록 느리게 설정합니다. 설정 후 화면을 두 번 탭하면 속도 조절이 완료됩니다.";
    });
    await _speak(message);
    _startRepeatingSpeedPrompt();
  }

  void _startRepeatingSpeedPrompt() async {
    isRepeatingTts = true;
    while (isSpeedSetting && isRepeatingTts) {
      if (!isSpeaking) {
        await tts.setSpeechRate(speechRate);
        await tts.speak("속도조절설정");
      }
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  Future _completeSpeedSetting() async {
    isRepeatingTts = false;
    setState(() {
      isSpeedSetting = false;
      speedSetCompleted = true;
      message = "속도 조절이 완료되었습니다.";
    });
    await _speak(message);
    await Future.delayed(Duration(milliseconds: 500));
    await _showCameraGuide();
  }

  Future _showCameraGuide() async {
    setState(() {
      isCameraMode = true;
      analysisComplete = false;
      message = "화면을 두 번 탭하면 사진을 촬영합니다";
    });
    await _speak(message);
  }

  Future _analyzePicture() async {
    setState(() {
      isCameraMode = false;
      message = "TapSee가 분석중입니다";
      analysisComplete = false;
    });
    await _speak(message);
    await Future.delayed(Duration(seconds: 2));
    final intro =
        "안녕하세요 저희는 Tap See입니다. 저희는 AI를 활용하여 시각 장애인을 위한 텍스트 분석 및 요약 내용을 음성으로 제공하는 프로그램을 만들었습니다. 저희는 음성안내에 따라 간단한 터치와 드래그로만 앱을 작동 시킬 수 있는 간편하고 편리한 어플리케이션 입니다.";
    setState(() {
      message = intro;
      analysisComplete = true;
    });
    await _speak(intro);
  }

  void _handleTap() async {
    tapCount++;
    if (tapCount == 2) {
      tapCount = 0;
      if (isSpeedSetting) {
        await _completeSpeedSetting();
      } else if (isCameraMode && !analysisComplete) {
        if (_cameraController.value.isInitialized) {
          await _cameraController.takePicture();
          await _analyzePicture();
        }
      }
    }
  }

  void _handleDrag(DragUpdateDetails details) {
    double deltaY = details.delta.dy;
    if (isSpeedSetting) {
      speechRate = (speechRate - deltaY * 0.005).clamp(0.1, 1.0);
      tts.setSpeechRate(speechRate);
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    double deltaY = dragStart.dy - details.globalPosition.dy;
    if (!isSpeedSetting && analysisComplete) {
      if (deltaY > 100) {
        setState(() {
          analysisComplete = false;
        });
        _showCameraGuide();
      } else if (deltaY < -100) {
        _speak(message);
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    tts.stop();
    isRepeatingTts = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => dragStart = d.localPosition,
      onPanUpdate: _handleDrag,
      onPanEnd: _handleDragEnd,
      onTap: _handleTap,
      child: Scaffold(
        backgroundColor: Color(0xFFFFE14D),
        body: Stack(
          children: [
            if (isCameraMode && !isSpeedSetting && !analysisComplete && _cameraController.value.isInitialized)
              Positioned.fill(
                child: CameraPreview(_cameraController),
              ),
            if (!isCameraMode || isSpeedSetting || analysisComplete)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  margin: const EdgeInsets.symmetric(horizontal: 24.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    border: Border.all(color: Colors.grey.shade600, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}



