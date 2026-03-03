# Habitual Publishing Checklist

## 1. Final Code Quality Pass

In Xcode, clear all red errors first, then address warnings by priority:

1. Build target warnings (icons/orientations/config).
2. Runtime/logic warnings.
3. Cosmetic warnings.

Notes:

- `Result of call to 'withAnimation' is unused` are compiler warnings, not lint errors.
- If you want a zero-warning portfolio build, convert calls to `_ = withAnimation(...) { ... }` where needed.

## 2. App Icon / Asset Sanity

- Ensure `AppIcon` is selected in Target -> General -> App Icons.
- Confirm all required iPhone/iPad + marketing icon slots are filled.
- Remove unreferenced files from image sets to avoid “unassigned child” warnings.

## 3. Create Clean Public Repo

From terminal:

```bash
cd "/Users/daniel/dev"
mkdir -p Habitual-public
rsync -av --exclude ".git" \
  "/Users/daniel/dev/Habit Tracker/ZynSleep" \
  "/Users/daniel/dev/Habit Tracker/ZynSleep.xcodeproj" \
  "/Users/daniel/dev/Habit Tracker/.gitignore" \
  "/Users/daniel/dev/Habit Tracker/README.md" \
  "/Users/daniel/dev/Habit Tracker/docs" \
  "/Users/daniel/dev/Habitual-public/"

cd "/Users/daniel/dev/Habitual-public"
git init
git add .
git commit -m "Initial Habitual portfolio release"
git branch -M main
git remote add origin <your-new-repo-url>
git push -u origin main
```

## 4. Add Demo Access

Best path for interactive demo:

1. Archive app (`Product -> Archive`).
2. Export `.ipa`.
3. Upload to Appetize.io.
4. Put the Appetize link in `README.md`.

Alternative:

- Upload to TestFlight and share public invite link in `README.md`.

## 5. README Final Touches

Add:

- 3-5 screenshots
- short demo GIF or video link
- architecture bullets
- “what I’d do next” section

## 6. Suggested GitHub Repo Description

`SwiftUI iOS habit tracker with dynamic custom trackers, sleep logging, and Apple Health-style insights charts.`
