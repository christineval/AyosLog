# Maintly predictive-maintenance documentation pack

This is an **implementation specification** to give to your coding agent, not executable features. It is intended for the existing AyosLog/Maintly Flutter + Riverpod + Drift project and its emerald light/dark Figma design.

**Read in this order:** `AGENTS_PREDICTIVE.md` → `PREDICTIVE_MAINTENANCE_SPEC.md` → `CATEGORY_FORMS.md` → `ARCHITECTURE_AND_CALCULATIONS.md` → `DATABASE_MIGRATION_PLAN.md`.

**Hand-off prompt:** “Read all files in this directory, the existing repository's AGENTS.md and DESIGN.md, and current Dart/Drift implementation. Follow AGENTS_PREDICTIVE.md stage-by-stage; start with Stage A and do not overwrite existing features. Add unit tests and report verified results and any unresolved blockers.”

**Important:** SQL is a reference fragment; adapt to your actual Supabase table definitions, never execute blind. No failure-risk machine learning is promised.
