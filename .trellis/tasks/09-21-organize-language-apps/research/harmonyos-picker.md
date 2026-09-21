# HarmonyOS Picker research

Date: 2026-09-22

Source: local DevEco SDK declarations under `D:\ProgramFiles\Huawei\DevEco Studio\sdk\default\openharmony\ets\api\@ohos.file.picker.d.ts`.

Confirmed APIs:

- `picker.DocumentViewPicker` is constructed with a `UIAbility` context and exposes `select(DocumentSelectOptions)` and `save(DocumentSaveOptions)`, returning document URI strings.
- `picker.DocumentSelectMode` includes `FILE`, `FOLDER`, and `MIXED`. The SDK notes that folder selection depends on device system capability; current declarations specifically mention folder support restrictions on some device classes.
- `picker.PhotoViewPicker` exposes `select(PhotoSelectOptions)` for media URI selection and `save(PhotoSaveOptions)` for saving media through the system picker.
- Picker APIs must be called from a `UIAbility`, which matches the existing `EntryAbility.ets` MethodChannel registration point.

Implementation consequence:

- Flutter should receive an opaque URI/payload from the native host and must not treat a content URI as a local file-system path.
- The native host must provide URI read/write operations or copy the selected URI into the app sandbox before returning a local path.
- The Dart service needs a file-level JSON fallback because directory selection can be unavailable on some HarmonyOS devices. A successful compile alone is not evidence that the directory picker works on a target phone.
