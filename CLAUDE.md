# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Irene Training is a Flutter mobile/web application for training content. It uses Supabase for authentication and backend services, with Riverpod for state management.

## Common Commands

```bash
# Run the app
flutter run

# Run on specific device
flutter run -d chrome    # Web
flutter run -d windows   # Windows desktop

# Get dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build for production
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
```

## Architecture

### Directory Structure
```
lib/
├── main.dart                    # App entry point with AuthWrapper
├── irene_design_system.dart     # Design system barrel export
├── core/                        # Shared infrastructure
│   ├── config/                  # Configuration (Supabase credentials)
│   ├── theme/                   # Design system (colors, typography, spacing)
│   ├── widgets/                 # Reusable UI components
│   └── services/                # Shared services
└── features/                    # Feature modules
    ├── auth/                    # Authentication (login, OTP)
    │   ├── screens/
    │   └── providers/
    └── learning/                # Learning content
        ├── screens/
        ├── widgets/
        ├── models/
        └── providers/
```

### Key Patterns

- **Feature-based organization**: Each feature (auth, learning) has its own screens, widgets, models, and providers subdirectories
- **AuthWrapper in main.dart**: Handles auth state and routes to LoginScreen or DirectoryScreen based on session
- **Supabase OTP Auth**: Uses phone number + OTP for authentication (no password)
- **Design System**: Custom components in `core/widgets/` (buttons, cards, input fields, tags/badges, toggle switches)

### Design System

- **Primary color**: Teal (#0D9488)
- **Font**: MiSansThai (Thai-optimized font with weights 100-800)
- **Colors**: Defined in `core/theme/app_colors.dart`
- **Typography**: Defined in `core/theme/app_typography.dart`
- **Spacing**: Defined in `core/theme/app_spacing.dart`

### State Management

Uses `flutter_riverpod` for state management. Provider files go in `features/*/providers/`.

### Backend

Supabase is initialized in `main.dart` with config from `core/config/supabase_config.dart`.

### Network Images (สำคัญมาก!)

**ทุกรูปที่โหลดจาก network ต้องมี timeout และ retry mechanism เสมอ** เพื่อ UX ที่ดี:

1. **Timeout 15 วินาที** - ถ้าโหลดไม่เสร็จภายในเวลา แสดง "โหลดช้า" + ปุ่มลองใหม่
2. **Error handling** - ถ้าโหลดไม่ได้ แสดง "โหลดรูปไม่สำเร็จ" + ปุ่มลองใหม่
3. **Progress indicator** - แสดง % ระหว่างโหลด (ถ้าทราบขนาดไฟล์)

ตัวอย่าง widget: ดู `_MedicineNetworkImage` ใน `lib/features/medicine/widgets/medicine_photo_item.dart`

**ห้ามใช้ `Image.network` หรือ `CachedNetworkImage` โดยตรง** โดยไม่มี timeout/retry!
