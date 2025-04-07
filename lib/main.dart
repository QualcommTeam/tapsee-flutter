// ✅ TapSee 완성본 with 오류 추적 추가

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TapSeeApp());
}

class TapSeeApp extends StatelessWidget {
  const TapSeeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const TapSeeSplash(),
      );
}

class TapSeeSplash extends StatelessWidget {
  const TapSeeSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: availableCameras(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return TapSeeHome(cameras: snapshot.data!);
        } else {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Image(
                image: AssetImage('assets/icons/tapsee_icon.png'),
                width: 120,
              ),
            ),
          );
        }
      },
    );
  }
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

  bool isSpeedSetting = false;
  bool isCameraMode = false;
  bool analysisComplete = false;
  bool isSpeaking = false;
  bool isRepeatingTts = false;
  bool cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    await _initializeCamera();
    _initTts();
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('firstLaunch') ?? true;

    await _speak("TapSee를 시작합니다");
    await Future.delayed(const Duration(milliseconds: 800));

    if (isFirst) {
      await prefs.setBool('firstLaunch', false);
      message = "음성 속도를 조절합니다. 위로 드래그하면 빠르게, 아래로 드래그하면 느리게 설정합니다. 화면을 두 번 탭하면 속도 조절이 완료됩니다.";
      _startSpeedSetting();
    } else {
      setState(() => isCameraMode = true);
      await _showCameraGuide();
    }
  }

  void _initTts() {
    tts.setSpeechRate(speechRate);
    tts.awaitSpeakCompletion(true);
  }

  Future<void> _speak(String text) async {
    await tts.stop();
    setState(() => isSpeaking = true);
    await tts.setSpeechRate(speechRate);
    await tts.speak(text);
    setState(() => isSpeaking = false);
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraController = CameraController(
        widget.cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController.initialize();
      await _cameraController.setFlashMode(FlashMode.off);
      setState(() => cameraInitialized = true);
    } catch (e) {
      print("카메라 초기화 실패: $e");
    }
  }

  void _startSpeedSetting() async {
    setState(() {
      isSpeedSetting = true;
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
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _completeSpeedSetting() async {
    isRepeatingTts = false;
    setState(() {
      isSpeedSetting = false;
      message = "속도 조절이 완료되었습니다.";
    });
    await _speak(message);
    await _showCameraGuide();
  }

  Future<void> _showCameraGuide() async {
    setState(() {
      isCameraMode = true;
      analysisComplete = false;
      message = "화면을 두 번 탭하면 사진을 촬영합니다";
    });
    await _speak(message);
  }

  Future<void> _analyzePicture() async {
    setState(() {
      isCameraMode = false;
      message = "TapSee가 분석 중입니다";
      analysisComplete = false;
    });
    await _speak(message);

    final XFile file = await _cameraController.takePicture();
    try {
      print("📷 사진 촬영 완료. 파일 경로: ${file.path}");
      var uri = Uri.parse("http://172.23.143.244:5000/ocr");
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      print("📤 이미지 첨부 완료. 서버에 전송 시작...");

      var response = await request.send().timeout(const Duration(seconds: 8));
      print("📥 서버 응답 수신 완료. 상태 코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        var body = await response.stream.bytesToString();
        print("📄 응답 본문: $body");
        var result = jsonDecode(body)['result'];
        setState(() {
          message = result;
          analysisComplete = true;
        });
        await _speak(result);
      } else {
        setState(() {
          message = "텍스트 분석에 실패했습니다. (${response.statusCode})";
          analysisComplete = true;
        });
        await _speak(message);
      }
    } catch (e, stack) {
      print("❗ 서버 통신 중 오류 발생: $e");
      print("🔍 오류 위치(StackTrace):\n$stack");
      setState(() {
        message = "서버 오류가 발생했습니다.";
        analysisComplete = true;
      });
      await _speak(message);
    }
  }

  void _handleTap() async {
    tapCount++;
    HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
    if (tapCount == 2) {
      tapCount = 0;
      if (isSpeedSetting) {
        await _completeSpeedSetting();
      } else if (isCameraMode && cameraInitialized && !analysisComplete) {
        await _analyzePicture();
      }
    }
  }

  void _handleDrag(DragUpdateDetails details) {
    if (isSpeedSetting) {
      speechRate = (speechRate - details.delta.dy * 0.005).clamp(0.1, 1.0);
      tts.setSpeechRate(speechRate);
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final deltaY = dragStart.dy - details.globalPosition.dy;
    if (!isSpeedSetting && analysisComplete) {
      if (deltaY > 100) _showCameraGuide();
      else if (deltaY < -100) _speak(message);
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onPanStart: (d) => dragStart = d.localPosition,
        onPanUpdate: _handleDrag,
        onPanEnd: _handleDragEnd,
        child: Scaffold(
          backgroundColor: const Color(0xFFFFE14D),
          body: Stack(
            children: [
              if (cameraInitialized && isCameraMode && !isSpeedSetting && !analysisComplete)
                Positioned.fill(child: CameraPreview(_cameraController)),
              if (isSpeedSetting || analysisComplete || (!isCameraMode && !cameraInitialized) || message.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade600),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

