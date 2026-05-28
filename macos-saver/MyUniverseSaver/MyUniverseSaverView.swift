import Foundation
import ScreenSaver
import AppKit

@objc(MyUniverseView)
public class MyUniverseView: ScreenSaverView {
    
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
        print("[MyUniverseSaver] setup called.")
        
        // Minimal Black Background
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        
        // Center Text
        let bundle = Bundle(for: type(of: self))
        let timestamp = bundle.object(forInfoDictionaryKey: "MyUniverseBuildTimestamp") as? String ?? "Unknown"
        
        let label = NSTextField(labelWithString: "MyUniverseSaver Native Shell Loaded\nBuild: \(timestamp)")
        label.textColor = .green
        label.font = NSFont.monospacedSystemFont(ofSize: 24, weight: .regular)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
    
    // MARK: - Lifecycle
    public override func startAnimation() {
        super.startAnimation()
        print("[MyUniverseSaver] startAnimation called.")
    }
    
    public override func stopAnimation() {
        super.stopAnimation()
        print("[MyUniverseSaver] stopAnimation called.")
    }
    
    public override func animateOneFrame() {
        // Minimal animation tick
    }
    
    // MARK: - Configuration
    public override var hasConfigureSheet: Bool {
        return true
    }
    
    public override var configureSheet: NSWindow? {
        print("[MyUniverseSaver] configureSheet called.")
        return MinimalOptionsWindowController.shared.window
    }
}
