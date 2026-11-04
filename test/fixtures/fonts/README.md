# Reference UI test fonts

These fonts are test-only fixtures loaded by `test/reference_ui_test.dart`.
They keep reference rendering independent of fonts downloaded into a developer's
or CI runner's Flutter SDK cache. They are not bundled into the application.

Copied from Flutter 3.41.6's `bin/cache/artifacts/material_fonts` directory.
The font archive recorded in `bin/internal/material_fonts.version` is
`flutter_infra_release/flutter/fonts/3012db47f3130e62f7cc0beabff968a33cbec8d8/fonts.zip`.

- Roboto regular, medium, and bold: see `roboto_license.txt`.
- Material Icons: see `materialicons_license.txt`.

Keep the license files when updating these fixtures.
