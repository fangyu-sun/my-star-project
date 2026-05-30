import Foundation
import ScreenSaver
import WebKit
import CoreLocation

@objc(MyUniverseView)
public class MyUniverseView: ScreenSaverView, CLLocationManagerDelegate {
    
    private var webView: WKWebView?
    private let locationManager = CLLocationManager()
    private let defaultsModuleName = "com.fangyu.MyUniverseSaver"
    private var optionsWindowController: OptionsWindowController?
    
    // Ultimate Fallback (Greenwich)
    private let fallbackLat: Double = 51.4779
    private let fallbackLon: Double = -0.0015
    private let fallbackCityName = "Greenwich"
    private let fallbackRegionName = "London"
    private let fallbackCountryName = "United Kingdom"
    private let fallbackCountryCode = "GB"
    private let fallbackTimezone = "Europe/London"
    
    // MARK: - Initialization
    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        
        let defaults = ScreenSaverDefaults(forModuleWithName: defaultsModuleName)
        let activeMode = defaults?.string(forKey: "activeMode") ?? "city"
        
        var finalLat = fallbackLat
        var finalLon = fallbackLon
        var finalCityName = fallbackCityName
        var finalRegionName = fallbackRegionName
        var finalCountryName = fallbackCountryName
        var finalCountryCode = fallbackCountryCode
        var finalTimezone = fallbackTimezone
        var finalUpdatedAt: Double = 0
        
        // Zero-Blocking Rendering: Read directly from appropriate persistence bucket
        switch activeMode {
        case "currentPosition":
            if let lat = defaults?.double(forKey: "currentPosition_lat"),
               let lon = defaults?.double(forKey: "currentPosition_lon"), lat != 0.0 || lon != 0.0 {
                finalLat = lat
                finalLon = lon
                finalCityName = defaults?.string(forKey: "currentPosition_cityName") ?? "Current Position"
                finalRegionName = ""
                finalCountryName = ""
                finalCountryCode = ""
                finalTimezone = defaults?.string(forKey: "currentPosition_timezone") ?? "" // Web engine will resolve this via tz-lookup
                finalUpdatedAt = defaults?.double(forKey: "currentPosition_updatedAt") ?? 0
            }
            // Trigger silent background fetch for NEXT session
            triggerSilentBackgroundLocationFetch()
            
        case "city":
            if let lat = defaults?.double(forKey: "city_lat"),
               let lon = defaults?.double(forKey: "city_lon"), lat != 0.0 || lon != 0.0 {
                finalLat = lat
                finalLon = lon
                finalCityName = defaults?.string(forKey: "city_cityName") ?? fallbackCityName
                finalRegionName = defaults?.string(forKey: "city_regionName") ?? ""
                finalCountryName = defaults?.string(forKey: "city_countryName") ?? ""
                finalCountryCode = defaults?.string(forKey: "city_countryCode") ?? ""
                finalTimezone = defaults?.string(forKey: "city_timezone") ?? fallbackTimezone
                finalUpdatedAt = defaults?.double(forKey: "city_updatedAt") ?? 0
            }
            
        case "manual":
            if let lat = defaults?.double(forKey: "manual_lat"),
               let lon = defaults?.double(forKey: "manual_lon") {
                finalLat = lat
                finalLon = lon
                finalCityName = "Manual Coordinates"
                finalRegionName = ""
                finalCountryName = ""
                finalCountryCode = ""
                finalTimezone = defaults?.string(forKey: "manual_timezone") ?? "" // Web engine will resolve this via tz-lookup
                finalUpdatedAt = defaults?.double(forKey: "manual_updatedAt") ?? 0
            }
            
        default:
            break
        }
        
        let lang = defaults?.string(forKey: "language") ?? "en"
        let displayFrequency = defaults?.integer(forKey: "displayFrequency") ?? 10
        let brightness = defaults?.double(forKey: "brightness") ?? 1.0
        let isDebug = defaults?.bool(forKey: "debug") ?? false
        
        let bundle = Bundle(for: type(of: self))
        let buildTimestamp = bundle.object(forInfoDictionaryKey: "MyUniverseBuildTimestamp") as? String ?? "Unknown"
        
        // Initialize WKWebView immediately without waiting
        initializeWebView(
            lat: finalLat, lon: finalLon, mode: activeMode,
            city: finalCityName, region: finalRegionName, country: finalCountryName,
            countryCode: finalCountryCode, timezone: finalTimezone, updatedAt: finalUpdatedAt,
            lang: lang, freq: displayFrequency == 0 ? 10 : displayFrequency,
            bright: brightness == 0.0 ? 1.0 : brightness,
            debug: isDebug, buildTs: buildTimestamp
        )
    }
    
    private func initializeWebView(
        lat: Double, lon: Double, mode: String, city: String, region: String,
        country: String, countryCode: String, timezone: String, updatedAt: Double,
        lang: String, freq: Int, bright: Double, debug: Bool, buildTs: String
    ) {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.defaultWebpagePreferences = prefs
        
        let scriptSource = """
        window.MY_UNIVERSE_CONFIG = {
            runtime: "screensaver",
            latitude: \(lat),
            longitude: \(lon),
            locationMode: "\(mode)",
            cityName: "\(city)",
            regionName: "\(region)",
            countryName: "\(country)",
            countryCode: "\(countryCode)",
            timezone: "\(timezone)",
            updatedAt: \(updatedAt),
            language: "\(lang)",
            brightness: \(bright),
            displayFrequency: \(freq),
            debug: \(debug ? "true" : "false"),
            buildTimestamp: "\(buildTs)"
        };
        """
        
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        webConfiguration.userContentController = userContentController
        webConfiguration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let wv = WKWebView(frame: self.bounds, configuration: webConfiguration)
            wv.autoresizingMask = [.width, .height]
            wv.setValue(false, forKey: "drawsBackground")
            self.addSubview(wv)
            self.webView = wv
            
            self.loadWebResource()
        }
    }
    
    private func loadWebResource() {
        guard let bundleURL = Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html", subdirectory: "web") else {
            return
        }
        let dirURL = bundleURL.deletingLastPathComponent()
        self.webView?.loadFileURL(bundleURL, allowingReadAccessTo: dirURL)
    }
    
    // MARK: - Background Location (Silent)
    private func triggerSilentBackgroundLocationFetch() {
        locationManager.delegate = self
        
        let authStatus: CLAuthorizationStatus
        if #available(macOS 11.0, *) {
            authStatus = locationManager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }
        
        // Only fetch if already authorized. ScreenSaver framework blocks dialogs anyway.
        if authStatus == .authorized || authStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            let defaults = ScreenSaverDefaults(forModuleWithName: defaultsModuleName)
            defaults?.set(loc.coordinate.latitude, forKey: "currentPosition_lat")
            defaults?.set(loc.coordinate.longitude, forKey: "currentPosition_lon")
            defaults?.set("Current Position", forKey: "currentPosition_cityName")
            defaults?.set(Date().timeIntervalSince1970, forKey: "currentPosition_updatedAt")
            defaults?.synchronize()
            // We do NOT update the active WebView here to prevent flashes. It will take effect next session.
        }
        manager.stopUpdatingLocation()
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
    }
    
    // MARK: - Lifecycle
    public override func startAnimation() {
        super.startAnimation()
    }
    
    public override func stopAnimation() {
        super.stopAnimation()
    }
    
    public override func animateOneFrame() {
    }
    
    // MARK: - Configuration
    public override var hasConfigureSheet: Bool {
        return true
    }
    
    public override var configureSheet: NSWindow? {
        optionsWindowController = OptionsWindowController()
        return optionsWindowController?.window
    }
}
