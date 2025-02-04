import Cocoa
import FlutterMacOS
import CoastAudio

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // prevent native symbols from being stripped
    CoastAudioSymbolKeeper.keep()
    return true
  }
}
