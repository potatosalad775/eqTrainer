# CHANGELOG

## v2.7.0 [2026-11-11]
- Added Ukrainian and Russian translations.
- Audio files are now converted by the app's own audio engine, so long files need far less memory.
- A clip that fails to load is now skipped instead of ending the session.
- The playlist now marks clips whose file is missing.
- Fixed a new session starting with the previous session's points and band count.
- Fixed bugs and improved performance.
- [Windows] Added an installer.
- [Linux] GStreamer is no longer needed. FFmpeg is used for M4A, AAC, AIFF and WMA.
- [Desktop] Only one copy of the app can run at a time.
