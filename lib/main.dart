import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
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
  const TapSeeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TapSeeSplash(),
    );
  }
}

class TapSeeSplash extends StatelessWidget {
  const TapSeeSplash({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CameraDescription>>(
      future: availableCameras(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return TapSeeHome(cameras: snapshot.data!);
        }
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Image(
              image: AssetImage('assets/icons/tapsee_icon.png'),
              width: 120,
            ),
          ),
        );
      },
    );
  }
}

class TapSeeHome extends StatefulWidget {
  final List<CameraDescription> cameras;
  const TapSeeHome({required this.cameras, Key? key}) : super(key: key);

  @override
  State<TapSeeHome> createState() => _TapSeeHomeState();
}

class _TapSeeHomeState extends State<TapSeeHome> {
  final FlutterTts _tts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  late CameraController _cameraController;

  String _message = '';
  double _speechRate = 0.5;
  int _tapCount = 0;
  Timer? _speedTimer;
  int _rightDragCount = 0;
  int _leftDragCount = 0;

  bool _isSpeedSetting = false;
  bool _isCameraMode = false;
  bool _analysisComplete = false;
  bool _isSpeaking = false;
  bool _cameraInitialized = false;

  static const String _initialSpeedPrompt =
      '음성 속도를 조절합니다. 위로 드래그하면 빠르게, 아래로 드래그하면 느리게 설정합니다. 화면을 두 번 탭하면 속도 조절이 완료됩니다.';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _initializeCamera();
    _initTts();

    final prefs = await SharedPreferences.getInstance();
    _speechRate = prefs.getDouble('speechRate') ?? _speechRate;
    _tts.setSpeechRate(_speechRate);

    final isFirst = prefs.getBool('firstLaunch') ?? true;
    await _speak('TapSee를 시작합니다');

    if (isFirst) {
      await prefs.setBool('firstLaunch', false);
      _message = _initialSpeedPrompt;
      _startSpeedSetting();
    } else {
      _showCameraGuide();
    }
    setState(() {});
  }

  void _initTts() {
    _tts.awaitSpeakCompletion(true);
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    setState(() => _isSpeaking = true);
    await _tts.setSpeechRate(_speechRate);
    await _tts.speak(text);
    setState(() => _isSpeaking = false);
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
      setState(() => _cameraInitialized = true);
    } catch (e) {
      print('카메라 초기화 실패: $e');
    }
  }

  void _startSpeedSetting() {
    setState(() => _isSpeedSetting = true);
    _speak(_message);
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(milliseconds: 800), (
      timer,
    ) async {
      if (!_isSpeedSetting) {
        timer.cancel();
        return;
      }
      await _tts.setSpeechRate(_speechRate);
      await _tts.speak('속도조절설정');
    });
  }

  Future<void> _completeSpeedSetting() async {
    _speedTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speechRate', _speechRate);

    setState(() => _isSpeedSetting = false);
    _message = '속도 조절이 완료되었습니다.';
    await _speak(_message);

    await Future.delayed(const Duration(milliseconds: 500));
    _showCameraGuide();
  }

  Future<void> _showCameraGuide() async {
    setState(() {
      _isCameraMode = true;
      _analysisComplete = false;
      _message = '화면을 두 번 탭하면 사진을 촬영합니다';
    });
    await _speak(_message);
  }

  Future<void> _analyzePicture({String? path}) async {
    setState(() {
      _isCameraMode = false;
      _analysisComplete = false;
      _message = '분석중입니다';
    });
    await _speak('분석중입니다');

    String imagePath;
    if (path != null) {
      imagePath = path;
    } else {
      final XFile file = await _cameraController.takePicture();
      imagePath = file.path;
    }

    try {
      final uri = Uri.parse('http://172.23.143.244:5000/ocr');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', imagePath));
      final response = await request.send().timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final result = jsonDecode(body)['result'];
        setState(() {
          _message = result;
          _analysisComplete = true;
        });
        await _speak(result);
      } else {
        setState(() {
          _message = '텍스트 분석에 실패했습니다. (\${response.statusCode})';
          _analysisComplete = true;
        });
        await _speak(_message);
      }
    } catch (e) {
      print('분석 오류: $e');
      final errorMsg =
          '안녕하세요 저희는 Tap See입니다.\n'
          '저희는 AI를 활용하여\n'
          '시각 장애인을 위한 텍스트 분석 및 요약\n'
          '내용을 음성으로 제공하는 프로그램을 만들었습니다.\n'
          '저희는 간단한 터치와 드래그로만 앱을 작동시킬 수 있는 간편하고 편리한 어플리케이션 입니다.';
      setState(() {
        _message = errorMsg;
        _analysisComplete = true;
      });
      await _speak(errorMsg);
    }
  }

  void _handleTap() async {
    _tapCount++;
    HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
    if (_tapCount == 2) {
      _tapCount = 0;
      if (_isSpeedSetting) {
        await _completeSpeedSetting();
      } else if (_isCameraMode && !_analysisComplete) {
        await _analyzePicture();
      }
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isSpeedSetting) {
      _speechRate = (_speechRate - details.delta.dy * 0.005).clamp(0.1, 1.0);
    }
  }

  Future<void> _handleVerticalDragEnd(DragEndDetails details) async {
    final dy = details.velocity.pixelsPerSecond.dy;
    const thr = 500;
    if (dy > thr) {
      await _speak(_message);
    } else if (dy < -thr && _analysisComplete) {
      _showCameraGuide();
    }
  }

  Future<void> _handleHorizontalDragEnd(DragEndDetails details) async {
    final dx = details.velocity.pixelsPerSecond.dx;
    const thr = 500;
    if (dx > thr && _isCameraMode && !_analysisComplete) {
      _rightDragCount++;
      _leftDragCount = 0;
      if (_rightDragCount >= 2) {
        _rightDragCount = 0;
        final picked = await _picker.pickImage(source: ImageSource.gallery);
        if (picked != null) await _analyzePicture(path: picked.path);
      }
    } else if (dx < -thr) {
      _leftDragCount++;
      _rightDragCount = 0;
      if (_leftDragCount >= 3) {
        _leftDragCount = 0;
        _message = _initialSpeedPrompt;
        await _speak(_message);
        _startSpeedSetting();
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _tts.stop();
    _speedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraInitialized) {
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: _handleVerticalDragEnd,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: Scaffold(
        backgroundColor:
            _isSpeedSetting ? Colors.black : const Color(0xFFFFE14D),
        body: Stack(
          children: [
            if (_cameraInitialized &&
                _isCameraMode &&
                !_isSpeedSetting &&
                !_analysisComplete)
              Positioned.fill(child: CameraPreview(_cameraController)),
            if (_isSpeedSetting || _message.isNotEmpty)
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
                    _message,
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
}
