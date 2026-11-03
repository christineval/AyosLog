# AyosLog Design System

Source of visual direction: AyosLog Figma file `3q0U37sFvN6hEUQpIHqlde`, theme page **00 — AyosLog Theme System**. Light mode uses soft light surfaces inspired by the user's purple reference (without purple); dark mode borrows charcoal and layered panels from the dark reference (without orange). All brand accents are emerald green.

## Tokens

| Semantic token | Light | Dark | Dart location |
|---|---|---|---|
| Background | `#F4F6FA` | `#0B0D10` | `AppColors` |
| Surface | `#FFFFFF` | `#1C1F24` | `AppColors` |
| Elevated/input | `#EFF2F6` | `#292C32` | `AppColors` |
| Accent | `#17966C` | `#26BA88` | `AppColors` |
| Accent subtle | `#DCF6EB` | `#1F3B31` | `AppColors` |
| Primary text | `#192536` | `#F3F5F7` | `AppColors` |
| Secondary text | `#667385` | `#ADB5C0` | `AppColors` |
| Border | `#E5EAF0` | `#353941` | `AppColors` |
| Warning | `#DA972D` | `#F5BF60` | `AppColors` |
| Error | `#D84F56` | `#FB737A` | `AppColors` |
| Info | `#3978D5` | `#76A8FF` | `AppColors` |

Spacing `4/8/12/16/24/32`; page inset `22`; card radius `23`, inputs/buttons `16`, floating nav `29`. Typography uses system sans/Roboto until a licensed custom font is packaged; key sizes `27/18/15/14/12` as `AppTypography` roles.

## Component usage

Predictive Insights uses the same tokens, `AppPageBar`, `AppFormLayout`,
`AppButton`, `AppField`, `AppDropdown`, `AppCard` and labelled `StatusPill`.
Category forms are rendered from typed domain definitions. Reading charts have
semantic reading descriptions and use only theme colors. Numeric forecasts,
condition review signals and stale-data badges stay distinct. Asset categories
and filters use the seven documented names, including Vehicle/Motorcycle.

The latest asset/service screenshots supplied by the user guide the form and detail layout: compact uppercase section labels, headings, labels above filled rounded inputs, mint summary cards and green side markers. Primary asset and maintenance actions stay visible in the footer with horizontally and vertically centered labels. Both themes use the existing semantic tokens; date pickers and date selection controls retain their neutral light/dark treatment.

- `AppPageBar` supplies the overview/service-entry headings. `AppFormLayout` scrolls the content and keeps its primary action visible above the keyboard/bottom navigation.
- `AppAccentCard` supplies the side-marked overview and history cards. New service details show real saved work, cost, performer and receipt data; unsupported PDF/export/edit/warranty actions are not shown.
- `AppField` and `AppDropdown` use visible labels above the field. Optional reminder/usage inputs on the service form are grouped in an expandable section.

- `AppButton` wraps themed Elevated/Outlined buttons; supports loading and disabled states.
- `AppField` centralizes text-input visuals, validation and labels.
- `AppCard` centralizes elevation-free bordered cards, padding and InkWell feedback.
- `StatusPill` uses semantic success/warning/error tones and visible text.
- `AppTheme` owns Material theme configuration for buttons, text fields, cards, chips and navigation.
- `AppShell` owns four-item bottom navigation (Home, Assets, Calendar, Settings).
- `showAppDatePicker` uses neutral surface/text colors for calendars in both themes, including selected dates and manual date entry. Asset category pills indicate selection without checkmarks.
- Routes use `NoTransitionPage`: page pushes and back navigation have no slide animation.
- `AppDropdown` fills its available width and anchors a width-constrained, scrollable menu below the field, with viewport collision handling on small screens.
- `AppEmptyState` centers an icon above a title and supporting text in the available content area; Assets distinguishes an empty collection from an empty search result.
- `PredictionPanel` shows task-specific measures, source labels, limits, observations and cost comparisons with themed surfaces/text and explicit loading/error/empty states. No example data is displayed as a real recommendation. Task settings choose the measure; usage forms show only the selected task's counter or observation. Mileage controls require an explicit car designation.

## Visual principles

One dominant green CTA per screen; cards use soft rounded surfaces without heavy shadows; dark screens use layered near-black panels; no purple/orange accent. Test in both themes with 200% text size, keyboard open, and small devices. Minimum tap area 48 dp. Provide text labels in addition to status colors. No magic colors or radii inside feature widgets unless documenting a justified exception.

## Design-to-code checklist

Current code implements key visual patterns, not a pixel-identical Figma recreation. Before claiming parity, inspect every Figma artboard and compare assets, empty states, alignment, font and dark colors on devices. OCR receipt review is currently a form and not yet a dedicated preview screen.
