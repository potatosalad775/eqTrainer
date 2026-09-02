import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Was setWindowMinSize in main.dart, via the window_size plugin. It is a
    // constant, so a plugin, a method channel and a frame of Dart startup
    // bought nothing over setting it here — and the plugin has no Swift
    // Package Manager support, which Flutter is moving to require.
    //
    // minSize is the *frame* minimum (content plus titlebar), the same
    // property the plugin set, so the constraint is unchanged.
    //
    // The window title is not set here; it comes from CFBundleName. See
    // PRODUCT_DISPLAY_NAME in Configs/AppInfo.xcconfig.
    self.minSize = NSSize(width: 400, height: 480)
  }
}
