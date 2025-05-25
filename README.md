# TapSee
📱 AI 기반 OCR·음성 안내 앱 (시각장애인 지원용)

![한 컷 요약](app_flutter/assets/screenshots/your_summary.png)

---

## Table of Contents
- [소개](#소개)
- [주요 기능](#주요-기능)
- [설치·실행](#설치·실행)
- [시스템 아키텍처](#시스템-아키텍처)
- [스크린샷](#스크린샷)
- [로드맵](#로드맵)
- [기여](#기여)
- [라이선스](#라이선스)

---

## 소개
TapSee는 시각장애인을 위한 **AI OCR + 음성 안내** 모바일 앱입니다.  
Flutter 프론트엔드와 Flask 서버, Qualcomm QNN SDK EasyOCR 모델을 활용해 실시간 텍스트 인식을 제공합니다.

---

## 주요 기능
1. 📖 음성 안내 기반 속도 조절  
2. 📷 카메라 모드 전환 및 사진 촬영  
3. 🔄 드래그/탭 제스처로 재촬영·재출력·설정  
4. 🌈 밝고 심플한 UI 디자인

---

## 설치·실행

### Flutter 앱
```bash
cd app_flutter
flutter pub get
flutter run
