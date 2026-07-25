<div align="center">
  <img src="assets/examinar_logo.png" alt="Examinar Logo" width="120"/>
  <h1>Examinar</h1>
  <p><strong>A high-performance academic tracker and task allocation system built with Flutter & Isar.</strong></p>

  <p>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"/></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart"/></a>
    <a href="https://isar.dev"><img src="https://img.shields.io/badge/Isar-NoSQL-42A5F5" alt="Isar"/></a>
  </p>
</div>

---

## Downloads & Platform Availability

Pre-compiled production binaries are provided directly in this repository for supported host environments. For platforms requiring host-native compilation (macOS, Linux, iOS), build commands and automated CI configuration are documented below:

| Platform | Package Format | Binary Status | Installation / Build Command |
| :--- | :--- | :--- | :--- |
| **Android** | APK Package | [**Examinar-Android.apk**](https://github.com/Shashankinfernape/Examinar/raw/main/releases/Examinar-Android.apk) | Direct `.apk` Install (`60.5 MB`) |
| **Windows** | MSIX Package | [**Examinar-Windows.msix**](https://github.com/Shashankinfernape/Examinar/raw/main/releases/Examinar-Windows.msix) | Signed `.msix` Installer (`25.1 MB`) |
| **macOS** | Desktop Bundle | *Compile on macOS Host* | `flutter build macos --release` |
| **Linux** | Native Package | *Compile on Linux Host* | `flutter build linux --release` |
| **iOS** | iOS Package | *Compile on macOS Host* | `flutter build ipa --release` |

> *Note on Multi-Platform Builds:* Flutter requires platform-native compilers (Xcode for macOS/iOS, GTK/GCC for Linux, MSVC/Gradle for Windows/Android). Pre-compiled binaries for Android and Windows are built and served directly from this repository under [`/releases`](./releases).

---

## Technical Overview

Examinar is a specialized application designed for curriculum tracking, structured study unit organization, and daily schedule generation leading up to major examinations.

Unlike typical task managers, Examinar implements an automated task-chunking engine that distributes question units across target study hours while isolating high-priority exam dates onto a dedicated calendar layer.

### Key Capabilities

- **Mathematical Schedule Allocation:** Distributes target question sets across designated time blocks using a balanced partitioning algorithm:
  $$\text{Base} = \left\lfloor \frac{M}{N} \right\rfloor$$
  where $M$ represents total questions and $N$ represents allocated hours.
- **Embedded Isar Engine:** Utilizes Isar's zero-copy NoSQL database architecture for real-time reactivity and local persistence.
- **Dual-Layered Calendar Isolation:** Separates routine daily study events from core examination milestones to prevent calendar grid bloat.
- **Adaptive Layout Engine:** Dynamically transitions between a unified vertical layout on mobile devices ($w \le 720\text{px}$) and a multi-column responsive grid on tablet viewports ($w > 720\text{px}$).

---

## Architecture & Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | Flutter / Dart | Cross-platform client application |
| **Persistence** | Isar Database | Reactive, embedded NoSQL engine |
| **State Management** | Riverpod | Reactive state graph and dependency injection |
| **Calendar Engine** | Table Calendar | Custom high-priority exam grid |
| **Routing** | GoRouter | Declarative path-based navigation |

---

## Building from Source

### Prerequisites

- Flutter SDK (v3.24.0 or higher)
- Dart SDK (v3.5.0 or higher)
- C++ Build Tools (for Windows Desktop builds)

### Setup & Compilation

```bash
# Clone the repository
git clone https://github.com/Shashankinfernape/Examinar.git
cd Examinar

# Fetch dependencies
flutter pub get

# Run development target
flutter run
```

### Production Package Builds

```bash
# Build Android APK
flutter build apk --release

# Build Windows MSIX Package
dart run msix:create
```

---

## Design System

The client UI adheres to a modern dark-mode design specification:
- **Base Canvas:** Tonal Dark `#121212`
- **Surface Elevation:** Layered `#252525`
- **Primary Accent:** Samsung Blue (`#3E82F7`) and Premium Purple (`#1C54B2`)
- **Typography:** Space Grotesk / Inter with strict container constraints preventing visual overflow under scaling.
