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

**Supabase Project ID:** `amthgthvrxhlxpttioxu`

- ใช้ project ID นี้เมื่อใช้งาน MCP (Model Context Protocol) tools
- สำหรับจัดการ database, migrations, edge functions ผ่าน Supabase MCP

### Network Images (สำคัญมาก!)

**ทุกรูปที่โหลดจาก network ต้องใช้ `IreneNetworkImage` หรือ `IreneNetworkAvatar`** เพื่อ UX ที่ดี:

```dart
// สำหรับรูปทั่วไป
IreneNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  width: 200,
  height: 150,
  fit: BoxFit.cover,
  memCacheWidth: 400, // จำกัด memory usage
  compact: true,      // UI แบบ compact สำหรับรูปเล็ก
)

// สำหรับ avatar (วงกลม)
IreneNetworkAvatar(
  imageUrl: user.photoUrl,
  radius: 20,
  fallbackIcon: HugeIcon(icon: HugeIcons.strokeRoundedUser, ...),
)
```

**Features ของ IreneNetworkImage:**
1. **Timeout 15 วินาที** - ถ้าโหลดไม่เสร็จ แสดง "โหลดช้า" + ปุ่มลองใหม่
2. **Error handling** - ถ้าโหลดไม่ได้ แสดง "โหลดไม่สำเร็จ" + ปุ่มลองใหม่
3. **Memory optimization** - ใช้ `memCacheWidth` เพื่อไม่โหลดรูปใหญ่เกินไปเข้า memory
4. **Retry mechanism** - กดลองใหม่ได้เมื่อ timeout หรือ error
5. **Compact mode** - สำหรับรูปเล็กๆ แสดงแค่ icon ไม่มีข้อความ

**ไฟล์:** `lib/core/widgets/network_image.dart`

**❌ ห้ามใช้โดยตรง:**
- `Image.network()` - ไม่มี timeout/retry
- `CachedNetworkImage()` - ต้อง wrap ด้วย timeout logic เอง
- `NetworkImage()` ใน `backgroundImage` - ไม่มี error handling

---

## Performance Guidelines (สำคัญมาก!)

### 1. หลีกเลี่ยง setState ที่ไม่จำเป็น

**ปัญหา:** `setState(() {})` ใน TextField `onChanged` จะ rebuild ทั้งหน้าทุกครั้งที่พิมพ์

```dart
// ❌ BAD - rebuild ทั้งหน้าทุกตัวอักษร
TextField(
  controller: _controller,
  onChanged: (v) => setState(() {}),
)

// ✅ GOOD - ใช้ ValueListenableBuilder rebuild เฉพาะส่วนที่ต้องการ
ValueListenableBuilder<TextEditingValue>(
  valueListenable: _controller,
  builder: (context, value, child) {
    final isDisabled = value.text.trim().isEmpty;
    return PrimaryButton(
      onPressed: isDisabled ? null : _handleSubmit,
    );
  },
)
```

### 2. ColorFiltered ใช้เฉพาะรูปจาก Network

**ปัญหา:** `ColorFiltered` เป็น GPU-intensive widget ห้ามใช้ใน list ที่ scroll ได้

```dart
// ❌ BAD - ใช้ ColorFiltered กับ emoji ใน GridView
ColorFiltered(
  colorFilter: ColorFilter.mode(Colors.grey, BlendMode.saturation),
  child: Text('🏆', style: TextStyle(fontSize: 24)),
)

// ✅ GOOD - ใช้ color property สำหรับ Text
Text('🏆', style: TextStyle(fontSize: 24, color: Colors.grey))

// ✅ GOOD - ใช้ ColorFiltered เฉพาะรูปจาก network (จำเป็นจริงๆ)
if (imageUrl != null) {
  return ColorFiltered(
    colorFilter: ColorFilter.mode(Colors.grey, BlendMode.saturation),
    child: IreneNetworkImage(imageUrl: imageUrl, ...),
  );
}
```

### 3. ใช้ cacheWidth สำหรับรูปใน List

**ปัญหา:** รูปใหญ่โหลดเข้า memory ทำให้แอปช้าและ crash ได้

```dart
// ❌ BAD - โหลดรูป full-size เข้า memory
CircleAvatar(
  backgroundImage: NetworkImage(user.photoUrl!),
)

// ✅ GOOD - จำกัดขนาดรูปที่โหลดเข้า memory
CircleAvatar(
  child: ClipOval(
    child: Image.network(
      user.photoUrl!,
      width: 24,
      height: 24,
      cacheWidth: 48, // 2x สำหรับ high DPI
      fit: BoxFit.cover,
    ),
  ),
)

// ✅ BETTER - ใช้ IreneNetworkAvatar
IreneNetworkAvatar(
  imageUrl: user.photoUrl,
  radius: 12,
)
```

### 4. สรุป Performance Checklist

| สิ่งที่ต้องตรวจ | วิธีแก้ |
|---------------|--------|
| `setState(() {})` ใน onChanged | ใช้ `ValueListenableBuilder` |
| `ColorFiltered` ใน list | ใช้ `color` property สำหรับ Text/Icon |
| `Image.network` ไม่มี cacheWidth | เพิ่ม `cacheWidth: size * 2` |
| `NetworkImage` ใน backgroundImage | ใช้ `IreneNetworkAvatar` แทน |
| Widget ใหญ่ rebuild บ่อย | แยกเป็น StatefulWidget ย่อย |
