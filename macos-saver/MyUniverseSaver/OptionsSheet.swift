import Cocoa
import ScreenSaver

class MinimalOptionsWindowController: NSWindowController {
    
    static let shared = MinimalOptionsWindowController()
    
    init() {
        let windowRect = NSRect(x: 0, y: 0, width: 300, height: 150)
        let window = NSPanel(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "MyUniverseSaver Options"
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let label = NSTextField(labelWithString: "Native options panel loaded.")
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        let closeBtn = NSButton(title: "Close", target: self, action: #selector(closePressed))
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.keyEquivalent = "\r"
        contentView.addSubview(closeBtn)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            
            closeBtn.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            closeBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func closePressed() {
        if let win = window {
            win.sheetParent?.endSheet(win)
        }
    }
}
