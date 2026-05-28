import Foundation
import ScreenSaver
import WebKit
import CoreLocation

class MyUniverseSaverView: ScreenSaverView, CLLocationManagerDelegate {
    
    private var webView: WKWebView?
    private let locationManager = CLLocationManager()
    private var runtimeLocationTimer: Timer?
    
    // Fallback default coordinates (Pyongyang)
    private let defaultLat: Double = 39.0392
    private let defaultLon: Double = 125.7625
    
    // MARK: - Initialization
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        startRuntimeLocationFetch()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        startRuntimeLocationFetch()
    }
    
    // MARK: - Runtime Location Provider
    private func startRuntimeLocationFetch() {
        locationManager.delegate = self
        
        let authStatus: CLAuthorizationStatus
        if #available(macOS 11.0, *) {
            authStatus = locationManager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }
        
        // If not authorized or restricted, skip directly to fallback
        if authStatus == .denied || authStatus == .restricted {
            finalizeWebView(location: nil)
            return
        }
        
        // Setup 4-second hard timeout
        runtimeLocationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.locationManager.stopUpdatingLocation()
            self?.finalizeWebView(location: nil)
        }
        
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let timer = runtimeLocationTimer, timer.isValid {
            timer.invalidate()
            runtimeLocationTimer = nil
            manager.stopUpdatingLocation()
            finalizeWebView(location: locations.last)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let timer = runtimeLocationTimer, timer.isValid {
            timer.invalidate()
            runtimeLocationTimer = nil
            manager.stopUpdatingLocation()
            finalizeWebView(location: nil)
        }
    }
    
    // MARK: - WebView Setup
    private func finalizeWebView(location: CLLocation?) {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.defaultWebpagePreferences = prefs
        
        let defaultsModuleName = "com.fangyu.MyUniverseSaver"
        let defaults = ScreenSaverDefaults(forModuleWithName: defaultsModuleName)
        
        let lang = defaults?.string(forKey: "language") ?? "zh"
        let brightness = defaults?.double(forKey: "brightness")
        let displayFrequency = defaults?.integer(forKey: "displayFrequency")
        let safeBrightness = brightness == 0 ? 1.0 : brightness ?? 1.0
        let safeFrequency = displayFrequency == 0 ? 10 : displayFrequency ?? 10
        
        // Final fallback constants (Perth)
        var finalLat: Double = -31.9523
        var finalLon: Double = 115.8613
        var finalLocationMode = "default"
        var finalCityName = "Perth"
        var finalRegionName = "Western Australia"
        var finalCountryName = "Australia"
        var finalCountryCode = "AU"
        var finalTimezone = "Australia/Perth"
        
        if let validLocation = location {
            // Priority 1: Runtime CoreLocation succeeded
            finalLat = validLocation.coordinate.latitude
            finalLon = validLocation.coordinate.longitude
            finalLocationMode = "runtimeCurrentLocation"
            finalCityName = "Current Location"
            finalRegionName = ""
            finalCountryName = ""
            finalCountryCode = ""
            finalTimezone = ""
        } else {
            // Priority 2: Fallback to ScreenSaverDefaults
            if let savedMode = defaults?.string(forKey: "locationMode"),
               let savedLat = defaults?.double(forKey: "latitude"),
               let savedLon = defaults?.double(forKey: "longitude") {
                
                // Exclude invalid (0.0, 0.0) from being used unless it was manually specified
                if (savedLat != 0.0 || savedLon != 0.0) || savedMode == "manual" {
                    finalLat = savedLat
                    finalLon = savedLon
                    finalLocationMode = savedMode
                    finalCityName = defaults?.string(forKey: "cityName") ?? ""
                    finalRegionName = defaults?.string(forKey: "regionName") ?? ""
                    finalCountryName = defaults?.string(forKey: "countryName") ?? ""
                    finalCountryCode = defaults?.string(forKey: "countryCode") ?? ""
                    finalTimezone = defaults?.string(forKey: "timezone") ?? ""
                }
            }
        }
        
        // Grab build timestamp from Info.plist
        let bundle = Bundle(for: type(of: self))
        let buildTimestamp = bundle.object(forInfoDictionaryKey: "MyUniverseBuildTimestamp") as? String ?? "unknown"
        
        print("--- MyUniverseSaver final config ---")
        print("latitude: \(finalLat)")
        print("longitude: \(finalLon)")
        print("locationMode: \(finalLocationMode)")
        print("cityName: \(finalCityName)")
        print("regionName: \(finalRegionName)")
        print("countryName: \(finalCountryName)")
        print("language: \(lang)")
        print("displayFrequency: \(safeFrequency)")
        print("buildTimestamp: \(buildTimestamp)")
        print("------------------------------------")
        
        let scriptSource = """
        window.MY_UNIVERSE_CONFIG = {
            runtime: "screensaver",
            latitude: \(finalLat),
            longitude: \(finalLon),
            locationMode: "\(finalLocationMode)",
            cityName: "\(finalCityName)",
            regionName: "\(finalRegionName)",
            countryName: "\(finalCountryName)",
            countryCode: "\(finalCountryCode)",
            timezone: "\(finalTimezone)",
            language: "\(lang)",
            brightness: \(safeBrightness),
            displayFrequency: \(safeFrequency),
            debug: \(defaults?.bool(forKey: "debug") ?? false),
            buildTimestamp: "\(buildTimestamp)"
        };
        """
        
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        webConfiguration.userContentController = userContentController
        
        // Suppress CORS issues for file://
        webConfiguration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        // Must dispatch to main thread for UI instantiation
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let wv = WKWebView(frame: self.bounds, configuration: webConfiguration)
            wv.autoresizingMask = [.width, .height]
            wv.setValue(false, forKey: "drawsBackground") // Transparent background
            self.addSubview(wv)
            self.webView = wv
            
            self.loadWebResource()
        }
    }
    
    private func loadWebResource() {
        guard let bundleURL = Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html", subdirectory: "web") else {
            print("MyUniverseSaver: Error - index.html not found in bundle resources.")
            return
        }
        
        let dirURL = bundleURL.deletingLastPathComponent()
        self.webView?.loadFileURL(bundleURL, allowingReadAccessTo: dirURL)
    }
    
    // MARK: - Lifecycle
    override func startAnimation() {
        super.startAnimation()
    }
    
    override func stopAnimation() {
        super.stopAnimation()
    }
    
    override func draw(_ rect: NSRect) {
        // Draw black background beneath webview
        NSColor.black.set()
        rect.fill()
    }
    
    override func animateOneFrame() {
        // Web engine handles animation entirely, no need to tick here.
    }
    
    // MARK: - Configuration
    override var hasConfigureSheet: Bool {
        return true
    }
    
    override var configureSheet: NSWindow? {
        return OptionsWindowController.shared.window
    }
}
