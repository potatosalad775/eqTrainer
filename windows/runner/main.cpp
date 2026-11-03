#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

#ifdef NDEBUG
// Each running copy keeps its own in-memory clip library and saves it whole, so
// a second one would overwrite the first one's changes. Debug builds are left
// out so 'flutter run' and integration tests work with the app open.
bool AnotherInstanceIsRunning() {
  ::CreateMutexW(nullptr, FALSE, L"Local\\kr.potatosalad775.eq_trainer");
  const DWORD error = ::GetLastError();
  // Access denied means it exists but belongs to an elevated copy.
  return error == ERROR_ALREADY_EXISTS || error == ERROR_ACCESS_DENIED;
}

void ShowRunningInstance() {
  // Class and title as set by Win32Window and wWinMain below. Absent if the
  // other copy has not created its window yet, which is fine.
  HWND window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"eqTrainer");
  if (window == nullptr) {
    return;
  }
  // The async form cannot hang here if the other copy has stopped responding.
  if (::IsIconic(window)) {
    ::ShowWindowAsync(window, SW_RESTORE);
  }
  ::SetForegroundWindow(window);
}
#endif

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
#ifdef NDEBUG
  if (AnotherInstanceIsRunning()) {
    ShowRunningInstance();
    return EXIT_SUCCESS;
  }
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(480, 720);
  if (!window.Create(L"eqTrainer", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
