import Cocoa
import ScreenSaver
import CoreLocation

struct City: Codable {
    let c: String
    let a: String
    let alt: [String]?
    let cc: String
    let cn: String
    let lat: Double
    let lon: Double
    let tz: String?
    let p: Int
}

class OptionsWindowController: NSWindowController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate, CLLocationManagerDelegate {
    
    static let shared = OptionsWindowController()
    let defaults = ScreenSaverDefaults(forModuleWithName: "com.sunfangyu.MyUniverseSaver")
    
    // CoreLocation
    let locationManager = CLLocationManager()
    
    // City Database
    var allCities: [City] = []
    var filteredCities: [City] = []
    
    // UI Elements
    let statusLabel = NSTextField(labelWithString: "Status: Initializing...")
    let currentLocationBtn = NSButton(title: "Use Current Location", target: nil, action: nil)
    
    let citySearchBox = NSComboBox()
    
    let latField = NSTextField()
    let lonField = NSTextField()
    let saveManualBtn = NSButton(title: "Save Manual", target: nil, action: nil)
    
    let langPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let freqSlider = NSSlider()
    let freqLabel = NSTextField(labelWithString: "10s")
    
    init() {
        let windowRect = NSRect(x: 0, y: 0, width: 450, height: 420)
        let window = NSPanel(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "My Universe Screensaver Options"
        super.init(window: window)
        
        locationManager.delegate = self
        
        setupUI()
        loadCitiesDatabase()
        updateStatusLabel()
        loadDefaults()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        // --- Status ---
        statusLabel.font = NSFont.boldSystemFont(ofSize: 12)
        stackView.addArrangedSubview(statusLabel)
        
        // --- Location Strategy 1: Current Location ---
        let currentLocBox = NSBox()
        currentLocBox.title = "Strategy 1: CoreLocation"
        currentLocBox.widthAnchor.constraint(equalToConstant: 410).isActive = true
        let currentLocStack = NSStackView()
        currentLocStack.orientation = .horizontal
        currentLocStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        currentLocationBtn.target = self
        currentLocationBtn.action = #selector(useCurrentLocation)
        currentLocStack.addArrangedSubview(currentLocationBtn)
        currentLocBox.contentView = currentLocStack
        stackView.addArrangedSubview(currentLocBox)
        
        // --- Location Strategy 2: City Search ---
        let citySearchBoxContainer = NSBox()
        citySearchBoxContainer.title = "Strategy 2: Offline City Search"
        citySearchBoxContainer.widthAnchor.constraint(equalToConstant: 410).isActive = true
        let cityStack = NSStackView()
        cityStack.orientation = .horizontal
        cityStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        citySearchBox.usesDataSource = true
        citySearchBox.dataSource = self
        citySearchBox.delegate = self
        citySearchBox.completes = true
        citySearchBox.widthAnchor.constraint(equalToConstant: 250).isActive = true
        cityStack.addArrangedSubview(NSTextField(labelWithString: "City:"))
        cityStack.addArrangedSubview(citySearchBox)
        let saveCityBtn = NSButton(title: "Save City", target: self, action: #selector(saveCity))
        cityStack.addArrangedSubview(saveCityBtn)
        citySearchBoxContainer.contentView = cityStack
        stackView.addArrangedSubview(citySearchBoxContainer)
        
        // --- Location Strategy 3: Manual ---
        let manualBox = NSBox()
        manualBox.title = "Strategy 3: Manual Coordinates"
        manualBox.widthAnchor.constraint(equalToConstant: 410).isActive = true
        let manualStack = NSStackView()
        manualStack.orientation = .horizontal
        manualStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        latField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        lonField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        saveManualBtn.target = self
        saveManualBtn.action = #selector(saveManualCoords)
        manualStack.addArrangedSubview(NSTextField(labelWithString: "Lat:"))
        manualStack.addArrangedSubview(latField)
        manualStack.addArrangedSubview(NSTextField(labelWithString: "Lon:"))
        manualStack.addArrangedSubview(lonField)
        manualStack.addArrangedSubview(saveManualBtn)
        manualBox.contentView = manualStack
        stackView.addArrangedSubview(manualBox)
        
        // --- Display Settings ---
        let displayBox = NSBox()
        displayBox.title = "Display Settings"
        displayBox.widthAnchor.constraint(equalToConstant: 410).isActive = true
        let displayStack = NSStackView()
        displayStack.orientation = .horizontal
        displayStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        langPopUp.addItems(withTitles: ["简体中文", "繁體中文", "English", "日本語"])
        freqSlider.minValue = 2
        freqSlider.maxValue = 30
        freqSlider.target = self
        freqSlider.action = #selector(sliderChanged(_:))
        freqSlider.widthAnchor.constraint(equalToConstant: 80).isActive = true
        freqLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true
        
        displayStack.addArrangedSubview(NSTextField(labelWithString: "Lang:"))
        displayStack.addArrangedSubview(langPopUp)
        displayStack.addArrangedSubview(NSTextField(labelWithString: "Freq:"))
        displayStack.addArrangedSubview(freqSlider)
        displayStack.addArrangedSubview(freqLabel)
        displayBox.contentView = displayStack
        stackView.addArrangedSubview(displayBox)
        
        // --- Bottom Buttons ---
        let btnContainer = NSStackView()
        btnContainer.orientation = .horizontal
        btnContainer.spacing = 20
        let closeBtn = NSButton(title: "Close & Apply Settings", target: self, action: #selector(closePressed))
        closeBtn.keyEquivalent = "\r"
        btnContainer.addArrangedSubview(closeBtn)
        stackView.addArrangedSubview(btnContainer)
    }
    
    // MARK: - State Management
    private func updateStatusLabel() {
        let mode = defaults?.string(forKey: "locationMode") ?? "default"
        let lat = defaults?.double(forKey: "latitude") ?? -31.9523
        let lon = defaults?.double(forKey: "longitude") ?? 115.8613
        let cName = defaults?.string(forKey: "cityName") ?? "Perth"
        
        var statusStr = "Mode: \(mode.uppercased()) | "
        if mode == "city" || mode == "default" || mode == "currentLocation" {
            let cn = defaults?.string(forKey: "countryName") ?? "Australia"
            statusStr += "\(cName), \(cn) (Lat: \(String(format: "%.2f", lat)), Lon: \(String(format: "%.2f", lon)))"
        } else {
            statusStr += "Lat: \(String(format: "%.2f", lat)), Lon: \(String(format: "%.2f", lon))"
        }
        
        statusLabel.stringValue = "Current Saved: " + statusStr
        
        latField.stringValue = "\(lat)"
        lonField.stringValue = "\(lon)"
    }
    
    private func loadDefaults() {
        let lang = defaults?.string(forKey: "language") ?? "zh"
        switch lang {
        case "zh": langPopUp.selectItem(at: 0)
        case "zh-TW": langPopUp.selectItem(at: 1)
        case "en": langPopUp.selectItem(at: 2)
        case "ja": langPopUp.selectItem(at: 3)
        default: langPopUp.selectItem(at: 0)
        }
        
        let freq = defaults?.integer(forKey: "displayFrequency") ?? 10
        let safeFreq = freq == 0 ? 10 : freq
        freqSlider.integerValue = safeFreq
        freqLabel.stringValue = "\(safeFreq)s"
    }
    
    @objc func sliderChanged(_ sender: NSSlider) {
        freqLabel.stringValue = "\(sender.integerValue)s"
    }
    
    // MARK: - Save Actions
    @objc private func closePressed() {
        // Save display settings on close
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
    
    @objc private func saveManualCoords() {
        if let lat = Double(latField.stringValue), let lon = Double(lonField.stringValue) {
            if lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                defaults?.set(lat, forKey: "latitude")
                defaults?.set(lon, forKey: "longitude")
                defaults?.set("manual", forKey: "locationMode")
                defaults?.set("Manual Coordinates", forKey: "cityName")
                defaults?.synchronize()
                updateStatusLabel()
            } else {
                showAlert("Invalid Coordinates", "Latitude must be between -90 and 90, Longitude between -180 and 180.")
            }
        }
    }
    
    @objc private func saveCity() {
        let selectedIndex = citySearchBox.indexOfSelectedItem
        if selectedIndex >= 0 && selectedIndex < filteredCities.count {
            let city = filteredCities[selectedIndex]
            defaults?.set(city.lat, forKey: "latitude")
            defaults?.set(city.lon, forKey: "longitude")
            defaults?.set("city", forKey: "locationMode")
            defaults?.set(city.c, forKey: "cityName")
            defaults?.set(city.cn, forKey: "countryName")
            defaults?.set(city.cc, forKey: "countryCode")
            if let tz = city.tz { defaults?.set(tz, forKey: "timezone") }
            defaults?.synchronize()
            updateStatusLabel()
        }
    }
    
    // MARK: - CoreLocation
    @objc private func useCurrentLocation() {
        currentLocationBtn.title = "Locating..."
        currentLocationBtn.isEnabled = false
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocationBtn.title = "Use Current Location"
        currentLocationBtn.isEnabled = true
        if let loc = locations.last {
            defaults?.set(loc.coordinate.latitude, forKey: "latitude")
            defaults?.set(loc.coordinate.longitude, forKey: "longitude")
            defaults?.set("currentLocation", forKey: "locationMode")
            defaults?.set("Current Location", forKey: "cityName")
            defaults?.synchronize()
            updateStatusLabel()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        currentLocationBtn.title = "Use Current Location"
        currentLocationBtn.isEnabled = true
        showAlert("Location Error", error.localizedDescription)
    }
    
    // MARK: - Offline City Database
    private func loadCitiesDatabase() {
        guard let url = Bundle(for: type(of: self)).url(forResource: "cities", withExtension: "json") else {
            print("cities.json not found in bundle!")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            allCities = try JSONDecoder().decode([City].self, from: data)
            filteredCities = Array(allCities.prefix(20))
        } catch {
            print("Failed to parse cities.json: \(error)")
        }
    }
    
    // MARK: - NSComboBox Data Source & Delegate
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return filteredCities.count
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if index < filteredCities.count {
            let city = filteredCities[index]
            return "\(city.c), \(city.cn)"
        }
        return nil
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let comboBox = obj.object as? NSComboBox, comboBox == citySearchBox else { return }
        let searchString = comboBox.stringValue.lowercased()
        
        if searchString.isEmpty {
            filteredCities = Array(allCities.prefix(20))
        } else {
            let matches = allCities.filter { city in
                city.c.lowercased().hasPrefix(searchString) ||
                city.a.lowercased().hasPrefix(searchString) ||
                (city.alt?.contains(where: { $0.lowercased().hasPrefix(searchString) }) ?? false)
            }
            // Sort by population and take top 20
            filteredCities = Array(matches.sorted(by: { $0.p > $1.p }).prefix(20))
        }
        comboBox.reloadData()
    }
    
    private func showAlert(_ title: String, _ msg: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = msg
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: self.window!, completionHandler: nil)
    }
}
