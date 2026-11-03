# AyosLog

## Description

AyosLog is an offline-first mobile app for tracking asset maintenance. It helps users organize vehicles and household equipment, schedule recurring maintenance, record service history and costs, and review rule-based maintenance insights. Data is stored locally on the device.

## Features

- Manage assets across seven categories: Vehicle/Motorcycle, Air Conditioner, Refrigerator, Laptop, Water Filter, Washing Machine, and Custom/Other.
- Add category-specific asset details, search and filter assets, and archive assets while preserving service history.
- Set recurring maintenance plans, first due dates, and reminder lead times for in-app upcoming maintenance lists.
- View upcoming maintenance and forecast dates in a chronological calendar list.
- Record services, costs, performers, and receipts; completing a linked service updates the maintenance plan's next due date.
- Review task-specific maintenance recommendations based on time, usage counters, condition checks, and user-entered manufacturer references.
- Track usage trends, correct readings and service records, and compare task-specific maintenance costs.
- Extract raw text from receipt images with on-device OCR and review or edit the extracted text.
- Switch between light, dark, and system themes, with the selected preference saved locally.

## Technologies Used

- **Flutter and Dart** for the mobile app and Material UI.
- **Riverpod** for state management with feature-first Clean Architecture and MVVM.
- **Drift and SQLite** for local data storage and migrations.
- **GoRouter** for navigation.
- **Google ML Kit Text Recognition** for on-device receipt OCR.
- **Image Picker** for selecting receipt images.
- **SharedPreferences** for saved theme preferences.
- **Build Runner and Drift Dev** for database code generation.
- **Flutter Test and Integration Test** for automated testing.

## Running the App

Install Flutter with Dart and configure the Android SDK and an emulator or connected Android device. Running on iOS requires macOS and Xcode.

From the project directory, install dependencies, generate database code, and launch the app:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

If Android or iOS platform folders are missing, generate them before running the commands above:

```sh
flutter create --platforms=android,ios .
```

To choose a specific connected device:

```sh
flutter devices
flutter run -d <device-id>
```
