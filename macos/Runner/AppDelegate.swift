import Cocoa
import FlutterMacOS
import CoastAudio

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // prevent native symbols from being stripped
    CoastAudioSymbolKeeper.keep()
    return true
  }
}
