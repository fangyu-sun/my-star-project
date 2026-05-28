import Cocoa
import ScreenSaver

class OptionsWindowController: NSWindowController {
    
    static let shared = OptionsWindowController()
    
    let defaults = ScreenSaverDefaults(forModuleWithName: "com.sunfangyu.MyUniverseSaver")
    
    // UI Elements
    let latField = NSTextField()
    let lonField = NSTextField()
    let langPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let freqSlider = NSSlider()
    let freqLabel = NSTextField(labelWithString: "10s")
    
    init() {
        let windowRect = NSRect(x: 0, y: 0, width: 350, height: 260)
        let window = NSPanel(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "My Universe Screensaver Options"
        
        super.init(window: window)
        
        setupUI()
        loadDefaults()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
        
        // --- Latitude ---
        let latContainer = NSStackView()
        latContainer.orientation = .horizontal
        let latLabel = NSTextField(labelWithString: "Latitude:")
        latLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        latField.widthAnchor.constraint(equalToConstant: 120).isActive = true
        latContainer.addArrangedSubview(latLabel)
        latContainer.addArrangedSubview(latField)
        stackView.addArrangedSubview(latContainer)
        
        // --- Longitude ---
        let lonContainer = NSStackView()
        lonContainer.orientation = .horizontal
        let lonLabel = NSTextField(labelWithString: "Longitude:")
        lonLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        lonField.widthAnchor.constraint(equalToConstant: 120).isActive = true
        lonContainer.addArrangedSubview(lonLabel)
        lonContainer.addArrangedSubview(lonField)
        stackView.addArrangedSubview(lonContainer)
        
        // --- Language ---
        let langContainer = NSStackView()
        langContainer.orientation = .horizontal
        let langLabel = NSTextField(labelWithString: "Language:")
        langLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        langPopUp.addItems(withTitles: ["简体中文", "繁體中文", "English", "日本語"])
        langPopUp.widthAnchor.constraint(equalToConstant: 120).isActive = true
        langContainer.addArrangedSubview(langLabel)
        langContainer.addArrangedSubview(langPopUp)
        stackView.addArrangedSubview(langContainer)
        
        // --- Frequency ---
        let freqContainer = NSStackView()
        freqContainer.orientation = .horizontal
        let freqTitle = NSTextField(labelWithString: "Tick Freq:")
        freqTitle.widthAnchor.constraint(equalToConstant: 80).isActive = true
        freqSlider.minValue = 2
        freqSlider.maxValue = 30
        freqSlider.widthAnchor.constraint(equalToConstant: 90).isActive = true
        freqSlider.target = self
        freqSlider.action = #selector(sliderChanged(_:))
        
        freqLabel.widthAnchor.constraint(equalToConstant: 25).isActive = true
        
        freqContainer.addArrangedSubview(freqTitle)
        freqContainer.addArrangedSubview(freqSlider)
        freqContainer.addArrangedSubview(freqLabel)
        stackView.addArrangedSubview(freqContainer)
        
        // --- Buttons ---
        let btnContainer = NSStackView()
        btnContainer.orientation = .horizontal
        btnContainer.spacing = 20
        
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        let okBtn = NSButton(title: "OK", target: self, action: #selector(okPressed))
        okBtn.keyEquivalent = "\r"
        
        btnContainer.addArrangedSubview(cancelBtn)
        btnContainer.addArrangedSubview(okBtn)
        stackView.addArrangedSubview(btnContainer)
    }
    
    @objc func sliderChanged(_ sender: NSSlider) {
        freqLabel.stringValue = "\(sender.integerValue)s"
    }
    
    private func loadDefaults() {
        let lat = defaults?.double(forKey: "latitude") ?? 39.9042
        let lon = defaults?.double(forKey: "longitude") ?? 116.4074
        let lang = defaults?.string(forKey: "language") ?? "zh"
        let displayFrequency = defaults?.integer(forKey: "displayFrequency")
        let safeFrequency = displayFrequency == 0 ? 10 : displayFrequency!
        
        latField.stringValue = "\(lat)"
        lonField.stringValue = "\(lon)"
        
        switch lang {
        case "zh": langPopUp.selectItem(at: 0)
        case "zh-TW": langPopUp.selectItem(at: 1)
        case "en": langPopUp.selectItem(at: 2)
        case "ja": langPopUp.selectItem(at: 3)
        default: langPopUp.selectItem(at: 0)
        }
        
        freqSlider.integerValue = safeFrequency
        freqLabel.stringValue = "\(safeFrequency)s"
    }
    
    @objc private func okPressed() {
        let lat = Double(latField.stringValue) ?? 39.9042
        let lon = Double(lonField.stringValue) ?? 116.4074
        defaults?.set(lat, forKey: "latitude")
        defaults?.set(lon, forKey: "longitude")
        
        var langCode = "zh"
        switch langPopUp.indexOfSelectedItem {
        case 0: langCode = "zh"
        case 1: langCode = "zh-TW"
        case 2: langCode = "en"
        case 3: langCode = "ja"
        default: langCode = "zh"
        }
        defaults?.set(langCode, forKey: "language")
        
        defaults?.set(freqSlider.integerValue, forKey: "displayFrequency")
        defaults?.synchronize()
        
        if let win = window {
            win.sheetParent?.endSheet(win)
        }
    }
    
    @objc private func cancelPressed() {
        if let win = window {
            win.sheetParent?.endSheet(win)
        }
    }
}
