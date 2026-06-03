# Exam Command Center (Time Tracker)

## Project Overview
**Exam Command Center** is a specialized, responsive Flutter application designed to help users track academic courses, organize study units, and dynamically schedule tasks (questions) leading up to major exams. It targets both mobile and tablet form factors, utilizing a premium Samsung One UI-inspired dark mode aesthetic.

## Tech Stack
- **Framework:** Flutter (Dart)
- **Local Database:** Isar (High-performance NoSQL database for Flutter)
- **State Management:** Riverpod
- **Calendar Engine:** `table_calendar` (Replaced Syncfusion `SfCalendar`)
- **Routing:** `go_router`

## Core Data Models (Isar)
1. **Course**: The top-level academic subject. Stores the subject's name, visual theme (color/icon), and importantly, the `examDate`.
2. **Unit**: Sub-divisions of a Course (e.g., chapters, modules, or specific topics).
3. **Question**: The atomic tasks or problems assigned to a Unit. They possess completion statuses and string titles. (Note: Embedded star ratings `[★☆]` are programmatically scrubbed during UI rendering).
4. **PlannerEvent**: Scheduled time blocks. These bridge the gap between time and tasks. Standard events map specific `questionIds` to 1-hour duration blocks. Exams are generated dynamically from Course `examDate`s.

## Key Features & Architecture

### 1. Tablet-Responsive Grid System
The application utilizes `SliverLayoutBuilder` to detect screen width. On mobile phones, items (like Courses) render as vertical lists. On tablets (width > 720px), the UI seamlessly transitions into a responsive `SliverGrid` to maximize screen real estate.

### 2. Calendar Data Isolation
The primary `TableCalendar` (`planner_screen.dart`) acts strictly as an **Exam Tracker**. It exclusively queries and renders courses that possess an `examDate` (mapping them to 3-hour urgent blocks). Routine daily study tasks are deliberately isolated and hidden from this top-level grid to prevent visual clutter.

### 3. The Schedule Wizard & Mathematical Chunking
When assigning tasks to a specific day in the `day_schedule_screen.dart`, the app uses a strict mathematical chunking algorithm to distribute multiple tasks across multiple selected hours.
- Formula: $Base = \lfloor M/N \rfloor$ (where $M$ = tasks, $N$ = hours).
- The system calculates the remainder and iteratively distributes the tasks into sequential 1-hour `PlannerEvent` blocks, preventing the UI from "squashing" all tasks into a single starting timestamp.

### 4. Deep Layered Aesthetics (Theming)
The application strictly rejects "flat" pure black `#000000` backgrounds. It relies on a layered depth hierarchy:
- **Base Canvas (Scaffolds/Backgrounds):** Deep Tonal Grey `#121212`.
- **Elevated Surfaces (Cards/Bottom Sheets):** `#252525`.
- **Accents:** Uses vibrant system colors like Samsung Blue (`#3E82F7`), Premium Purple (`#1C54B2`), and Urgent Red.
- **Typography:** Tablet-optimized integers (`18px`, `w500`) and strictly bounded Text containers (`maxHeight: 22`, `TextOverflow.ellipsis`) to permanently prevent pixel overflow errors.

## Recent Systemic Reconstructions (June 2026)
- **Calendar Migration**: Completely ripped out `SfCalendar` and successfully integrated `table_calendar` to resolve compilation and memory controller issues.
- **Regex Scrubbing**: Deployed robust regex `RegExp(r'[★☆]')` to physically purge embedded unicode stars from task strings on the fly.
- **Inner-Grid Tabular Layout**: Implemented a floating grid look for the calendar cells (though limited by the `table_calendar` package's lack of native `TableBorder` support, relying instead on clean margins and container decorations).

*This document serves as the master blueprint for the AI to understand the structural logic, aesthetic constraints, and database mechanics of the Exam Command Center.*
