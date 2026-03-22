//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_decoder
import audio_session
import connectivity_plus
import device_info_plus
import file_picker
import package_info_plus
import shared_preferences_foundation
import store_checker
import url_launcher_macos
import window_size

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioDecoderPlugin.register(with: registry.registrar(forPlugin: "AudioDecoderPlugin"))
  AudioSessionPlugin.register(with: registry.registrar(forPlugin: "AudioSessionPlugin"))
  ConnectivityPlusPlugin.register(with: registry.registrar(forPlugin: "ConnectivityPlusPlugin"))
  DeviceInfoPlusMacosPlugin.register(with: registry.registrar(forPlugin: "DeviceInfoPlusMacosPlugin"))
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  StoreCheckerPlugin.register(with: registry.registrar(forPlugin: "StoreCheckerPlugin"))
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
  WindowSizePlugin.register(with: registry.registrar(forPlugin: "WindowSizePlugin"))
}
