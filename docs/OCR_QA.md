# Receipt OCR verification

The app extracts Latin-script text with native ML Kit. Text remains editable and the user enters the cost; scans do not infer or save a total automatically.

`flutter test` checks full-text preservation beyond 450 characters, correction, empty/error/cancel handling, recognizer cleanup, and scan/save exclusion using mocked platform responses. These tests do not measure recognition accuracy.

`flutter test integration_test/receipt_ocr_test.dart -d <android-or-ios-device>` runs native ML Kit against a generated clean receipt with known text and a known decimal amount. This checks native integration and basic recognition only.

Verified on 2026-10-31: all 19 automated tests passed. The native smoke test passed on a Samsung SM A166P running Android 16 (API 36), recognizing `AYOSLOG SERVICE`, `Oil change`, and `TOTAL PHP 1250.00`. Real photographed receipts and iOS recognition have not been verified.

For real accuracy assessment, compare photographed receipts against manually transcribed reference text, including all amounts and decimal points. Cover sharp, rotated, blurred, faded, and shadowed receipts. Record incorrect or missing words and amounts; a clean-fixture pass alone is insufficient to claim accurate receipt scanning. No photographed receipt dataset is included in this repository.
