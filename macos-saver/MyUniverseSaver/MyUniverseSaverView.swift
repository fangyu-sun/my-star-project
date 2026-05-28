import Foundation
import ScreenSaver
import WebKit

class MyUniverseSaverView: ScreenSaverView {
    
    private var webView: WKWebView?
    
    // MARK: - Initialization
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setupWebView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }
    
    private func setupWebView() {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.defaultWebpagePreferences = prefs
        
        // Inject Configuration from ScreenSaverDefaults
        let defaults = ScreenSaverDefaults(forModuleWithName: "com.sunfangyu.MyUniverseSaver")
        
        let lat = defaults?.double(forKey: "latitude") ?? 39.9042
        let lon = defaults?.double(forKey: "longitude") ?? 116.4074
        let lang = defaults?.string(forKey: "language") ?? "zh"
        let brightness = defaults?.double(forKey: "brightness")
        let displayFrequency = defaults?.integer(forKey: "displayFrequency")
        
        let safeBrightness = brightness == 0 ? 1.0 : brightness ?? 1.0
        let safeFrequency = displayFrequency == 0 ? 10 : displayFrequency ?? 10
        
        let scriptSource = """
        window.MY_UNIVERSE_CONFIG = {
            runtime: "screensaver",
            latitude: \(lat),
            longitude: \(lon),
            language: "\(lang)",
            brightness: \(safeBrightness),
            displayFrequency: \(safeFrequency),
            debug: false
        };
        """
        
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        webConfiguration.userContentController = userContentController
        
        // Suppress CORS issues for file://
        webConfiguration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let wv = WKWebView(frame: self.bounds, configuration: webConfiguration)
        wv.autoresizingMask = [.width, .height]
        wv.setValue(false, forKey: "drawsBackground") // Transparent background
        self.addSubview(wv)
        self.webView = wv
        
        loadWebResource()
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
