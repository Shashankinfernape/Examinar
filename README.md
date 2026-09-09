<div align="center">
  <img src="assets/examinar_logo.png" alt="Examinar Logo" width="120"/>
  <h1>Examinar (Exam Command Center)</h1>
  <p><strong>A high-performance academic tracker, AI study builder, and task allocation system built with Flutter & Isar.</strong></p>

  <p>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"/></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart"/></a>
    <a href="https://isar.dev"><img src="https://img.shields.io/badge/Isar-NoSQL-42A5F5" alt="Isar"/></a>
  </p>
</div>

---

## 🌟 Overview

**Examinar** is a specialized, responsive application designed to act as the ultimate academic weapon for students. It goes beyond a typical to-do list by acting as a **dynamic study engine**. It helps users track courses, organize study units, mathematically schedule study tasks, and seamlessly digitize physical past papers using native AI integration.

Built with a premium Samsung One UI-inspired dark mode aesthetic, Examinar dynamically adapts to both mobile phones and tablets.

## 🚀 Key Features

### 🧠 The AI "Builder" Workflow (New!)
A highly advanced, cross-platform pipeline for digitizing physical exam papers:
* **Smart Image Staging:** A WhatsApp-style drop zone allows users to snap or drag-and-drop multiple photos of past exam papers. 
* **Direct App Handoff:** On Android, custom native Kotlin code seamlessly beams the images and a strict "pre-prompt" directly into the installed ChatGPT app (with fallbacks for Claude and Gemini). On PC, it uses automated browser handoffs.
* **Regex Parsing:** Once the AI generates the questions, the user pastes the text back into Examinar, which uses a smart Regex engine to instantly parse out the questions, assign marks (Part A, Part B, Part C), and convert them into trackable database items.

### 📊 Mathematical Schedule Allocation
Distributes target question sets across designated time blocks using a balanced partitioning algorithm, rather than squashing all tasks into a single hour.
* Formula: $\text{Base} = \lfloor \frac{M}{N} \rfloor$ (where $M$ = tasks, $N$ = allocated hours).

### 📅 Dual-Layered Calendar Isolation
Separates routine daily study events from core examination milestones. The top-level calendar exclusively tracks major `examDates` as urgent 3-hour blocks, preventing calendar grid bloat.

### ⚡ Embedded Isar Engine
Utilizes Isar's zero-copy NoSQL database architecture for real-time reactivity, incredible speed, and 100% offline local persistence.

---

## 📱 App Walkthrough

*(Screenshots will be added here soon!)*

### 1. The Dashboard (Calendar & Overview)
The central hub for tracking your most urgent exams.
* **[Screenshot Placeholder - Dashboard]**
* Displays the `TableCalendar` acting strictly as an **Exam Tracker**.
* Shows upcoming exams as highly visible color-coded blocks.

### 2. Course & Unit Management
The academic hierarchy where subjects are broken down into conquerable pieces.
* **[Screenshot Placeholder - Course Screen]**
* Beautifully rendered courses with their respective visual themes (color/icon).
* Tablet-responsive `SliverGrid` layout that maximizes screen real estate on larger devices.

### 3. The Schedule Wizard
Where the magic of mathematical chunking happens.
* **[Screenshot Placeholder - Schedule Wizard]**
* Users assign specific question units to specific days.
* The app automatically calculates the most efficient distribution of questions across the selected study hours.

### 4. The AI Paste Builder
The bridge between physical exam papers and digital study units.
* **[Screenshot Placeholder - AI Builder Step 1: Upload]**
* **[Screenshot Placeholder - AI Builder Step 2: Handoff to ChatGPT]**
* **[Screenshot Placeholder - AI Builder Step 3: Parsed Results]**
* Drop your photos, instantly open your preferred AI app, and paste back the perfectly formatted questions.

---

## 🛠️ Architecture & Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | Flutter / Dart | Cross-platform client application |
| **Persistence** | Isar Database | Reactive, embedded NoSQL engine |
| **State Management** | Riverpod | Reactive state graph and dependency injection |
| **Calendar Engine** | `table_calendar` | Custom high-priority exam grid |
| **Routing** | GoRouter | Declarative path-based navigation |

---

## 🎨 Design System

The client UI strictly adheres to a premium dark-mode design specification, rejecting "flat black" for a deep layered hierarchy:
- **Base Canvas:** Deep Tonal Grey `#121212`
- **Surface Elevation:** Layered Cards/Sheets `#252525`
- **Primary Accents:** Samsung Blue (`#3E82F7`), Premium Purple (`#1C54B2`), and Urgent Red.
- **Typography:** Space Grotesk / Inter with strictly bounded Text containers preventing pixel overflow under scaling.

---

## 📥 Downloads & Installation

Pre-compiled production application packages are available directly in this repository:

| Platform | Package | Download Link | Build Output |
| :--- | :--- | :--- | :--- |
| **Android** | APK Package | [**Examinar-Android.apk**](https://github.com/Shashankinfernape/Examinar/raw/main/releases/Examinar-Android.apk) | Direct `.apk` (`60.5 MB`) |
| **Windows** | MSIX Installer | [**Examinar-Windows.msix**](https://github.com/Shashankinfernape/Examinar/raw/main/releases/Examinar-Windows.msix) | Signed `.msix` (`25.1 MB`) |

> Both pre-compiled installer packages are stored directly in the [`/releases`](./releases) directory.

---

## 🏗️ Building from Source

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
