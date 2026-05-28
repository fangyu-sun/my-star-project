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
    let defaultsModuleName = "com.fangyu.MyUniverseSaver"
    let defaults: ScreenSaverDefaults?
    
    // CoreLocation
    let locationManager = CLLocationManager()
    var locationTimer: Timer?
    
    // City Database
    var allCities: [City] = []
    var filteredCities: [City] = []
    
    // UI Elements
    let citySearchBox = NSComboBox()
    let currentLocationBtn = NSButton(title: "Use Current Location", target: nil, action: nil)
    let inlineErrorLabel = NSTextField(labelWithString: "")
    
    let latField = NSTextField()
    let lonField = NSTextField()
    let saveManualBtn = NSButton(title: "Save Coordinates", target: nil, action: nil)
    
    let langPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let freqSlider = NSSlider()
    let freqLabel = NSTextField(labelWithString: "10s")
    
    init() {
        defaults = ScreenSaverDefaults(forModuleWithName: defaultsModuleName)
        // Adjusted window height for compactness
        let windowRect = NSRect(x: 0, y: 0, width: 480, height: 260)
        let window = NSPanel(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "My Universe Settings"
        super.init(window: window)
        
        locationManager.delegate = self
        
        migrateLegacyDefaults()
        setupUI()
        loadCitiesDatabase()
        loadAllDefaults()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Legacy Migration & Pyongyang Fallback
    private func migrateLegacyDefaults() {
        let lat = defaults?.double(forKey: "latitude") ?? 0.0
        let lon = defaults?.double(forKey: "longitude") ?? 0.0
        let mode = defaults?.string(forKey: "locationMode")
        let cityName = defaults?.string(forKey: "cityName")
        
        let isBadOldDefault = (lat == 0.0 && lon == 0.0) && (mode == "default" || mode == "DEFAULT" || mode == nil || cityName == "Perth" || cityName == "Default" || cityName == nil || cityName == "")
        
        // If it's an uninitialized state or the old 0.0 bug, migrate to strict Perth defaults
        if isBadOldDefault || mode == nil {
            defaults?.set(-31.9523, forKey: "latitude")
            defaults?.set(115.8613, forKey: "longitude")
            defaults?.set("default", forKey: "locationMode")
            defaults?.set("Perth", forKey: "cityName")
            defaults?.set("Western Australia", forKey: "regionName")
            defaults?.set("Australia", forKey: "countryName")
            defaults?.set("AU", forKey: "countryCode")
            defaults?.set("Australia/Perth", forKey: "timezone")
            defaults?.set(Date().timeIntervalSince1970, forKey: "locationUpdatedAt")
            defaults?.synchronize()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 15
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        // --- Location Setup Area ---
        let locLabel = NSTextField(labelWithString: "Location Configuration")
        locLabel.font = NSFont.boldSystemFont(ofSize: 14)
        mainStack.addArrangedSubview(locLabel)
        
        // City & Current Loc Row
        let cityRow = NSStackView()
        cityRow.orientation = .horizontal
        cityRow.spacing = 10
        
        let cityLabel = NSTextField(labelWithString: "City:")
        cityLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        cityLabel.alignment = .right
        
        citySearchBox.usesDataSource = true
        citySearchBox.dataSource = self
        citySearchBox.delegate = self
        citySearchBox.completes = true
        citySearchBox.widthAnchor.constraint(equalToConstant: 200).isActive = true
        citySearchBox.placeholderString = "Search e.g. Pyongyang"
        
        currentLocationBtn.target = self
        currentLocationBtn.action = #selector(useCurrentLocation)
        
        cityRow.addArrangedSubview(cityLabel)
        cityRow.addArrangedSubview(citySearchBox)
        cityRow.addArrangedSubview(currentLocationBtn)
        mainStack.addArrangedSubview(cityRow)
        
        // Inline Error Label
        inlineErrorLabel.textColor = .systemRed
        inlineErrorLabel.isEditable = false
        inlineErrorLabel.isSelectable = false
        inlineErrorLabel.isBordered = false
        inlineErrorLabel.backgroundColor = .clear
        inlineErrorLabel.font = NSFont.systemFont(ofSize: 11)
        inlineErrorLabel.isHidden = true
        
        let errorRow = NSStackView()
        errorRow.orientation = .horizontal
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 60).isActive = true
        errorRow.addArrangedSubview(spacer)
        errorRow.addArrangedSubview(inlineErrorLabel)
        mainStack.addArrangedSubview(errorRow)
        
        // Manual Coords Row
        let coordsRow = NSStackView()
        coordsRow.orientation = .horizontal
        coordsRow.spacing = 10
        
        let latLabel = NSTextField(labelWithString: "Latitude:")
        latLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        latLabel.alignment = .right
        latField.widthAnchor.constraint(equalToConstant: 75).isActive = true
        
        let lonLabel = NSTextField(labelWithString: "Longitude:")
        lonField.widthAnchor.constraint(equalToConstant: 75).isActive = true
        
        saveManualBtn.target = self
        saveManualBtn.action = #selector(saveManualCoords)
        
        coordsRow.addArrangedSubview(latLabel)
        coordsRow.addArrangedSubview(latField)
        coordsRow.addArrangedSubview(lonLabel)
        coordsRow.addArrangedSubview(lonField)
        coordsRow.addArrangedSubview(saveManualBtn)
        mainStack.addArrangedSubview(coordsRow)
        
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.widthAnchor.constraint(equalToConstant: 440).isActive = true
        mainStack.addArrangedSubview(separator2)
        
        // --- Display Settings ---
        let displayLabel = NSTextField(labelWithString: "Display Settings")
        displayLabel.font = NSFont.boldSystemFont(ofSize: 14)
        mainStack.addArrangedSubview(displayLabel)
        
        let displayRow = NSStackView()
        displayRow.orientation = .horizontal
        displayRow.spacing = 10
        
        langPopUp.addItems(withTitles: ["简体中文", "繁體中文", "English", "日本語"])
        
        freqSlider.minValue = 2
        freqSlider.maxValue = 30
        freqSlider.target = self
        freqSlider.action = #selector(sliderChanged(_:))
        freqSlider.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        displayRow.addArrangedSubview(NSTextField(labelWithString: "Language:"))
        displayRow.addArrangedSubview(langPopUp)
        displayRow.addArrangedSubview(NSTextField(labelWithString: "   Refresh:"))
        displayRow.addArrangedSubview(freqSlider)
        displayRow.addArrangedSubview(freqLabel)
        mainStack.addArrangedSubview(displayRow)
        
        // --- Bottom Buttons ---
        let btnContainer = NSStackView()
        btnContainer.orientation = .horizontal
        let closeBtn = NSButton(title: "Close & Apply Settings", target: self, action: #selector(closePressed))
        closeBtn.keyEquivalent = "\r"
        btnContainer.addArrangedSubview(closeBtn)
        
        let bottomStack = NSStackView()
        bottomStack.orientation = .horizontal
        bottomStack.alignment = .centerY
        bottomStack.widthAnchor.constraint(equalToConstant: 440).isActive = true
        bottomStack.addView(NSView(), in: .leading) // spacer
        bottomStack.addView(btnContainer, in: .trailing)
        
        mainStack.addArrangedSubview(bottomStack)
    }
    
    // MARK: - State Management
    private func loadAllDefaults() {
        let lat = defaults?.double(forKey: "latitude") ?? 39.0392
        let lon = defaults?.double(forKey: "longitude") ?? 125.7625
        latField.stringValue = "\(lat)"
        lonField.stringValue = "\(lon)"
        
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
    
    // MARK: - Actions
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
        hideError()
        if let lat = Double(latField.stringValue), let lon = Double(lonField.stringValue) {
            if lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                if lat == 0.0 && lon == 0.0 {
                    showInlineError("0.0, 0.0 is an invalid coordinate.")
                    return
                }
                defaults?.set(lat, forKey: "latitude")
                defaults?.set(lon, forKey: "longitude")
                defaults?.set("manual", forKey: "locationMode")
                defaults?.set("Manual Coordinates", forKey: "cityName")
                defaults?.synchronize()
                citySearchBox.stringValue = ""
            } else {
                showInlineError("Latitude must be between -90 and 90, Longitude between -180 and 180.")
            }
        } else {
            showInlineError("Please enter valid numeric coordinates.")
        }
    }
    
    // MARK: - CoreLocation
    @objc private func useCurrentLocation() {
        hideError()
        
        let authStatus: CLAuthorizationStatus
        if #available(macOS 11.0, *) {
            authStatus = locationManager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showInlineError("Could not get current location. Search a city or enter coordinates manually.")
            return
        }
        
        currentLocationBtn.title = "Locating..."
        currentLocationBtn.isEnabled = false
        
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.locationManager.stopUpdatingLocation()
            self?.handleLocationFailure(reason: "Could not get current location (Timeout). Search a city or enter coordinates manually.")
        }
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationTimer?.invalidate()
        currentLocationBtn.title = "Use Current Location"
        currentLocationBtn.isEnabled = true
        
        if let loc = locations.last {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            defaults?.set(lat, forKey: "latitude")
            defaults?.set(lon, forKey: "longitude")
            defaults?.set("savedCurrentLocation", forKey: "locationMode")
            defaults?.set("Current Location", forKey: "cityName")
            defaults?.set(Date().timeIntervalSince1970, forKey: "locationUpdatedAt")
            defaults?.synchronize()
            
            latField.stringValue = "\(lat)"
            lonField.stringValue = "\(lon)"
            citySearchBox.stringValue = ""
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationTimer?.invalidate()
        handleLocationFailure(reason: "Could not get current location. Search a city or enter coordinates manually.")
    }
    
    private func handleLocationFailure(reason: String) {
        currentLocationBtn.title = "Use Current Location"
        currentLocationBtn.isEnabled = true
        showInlineError(reason)
    }
    
    private func showInlineError(_ msg: String) {
        inlineErrorLabel.stringValue = msg
        inlineErrorLabel.isHidden = false
    }
    
    private func hideError() {
        inlineErrorLabel.isHidden = true
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
            var display = "\(city.c), "
            if let tz = city.tz, tz.contains("/") {
                let region = tz.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ") ?? ""
                display += "\(region), "
            }
            display += "\(city.cn)"
            return display
        }
        return nil
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        hideError()
        let selectedIndex = citySearchBox.indexOfSelectedItem
        if selectedIndex >= 0 && selectedIndex < filteredCities.count {
            let city = filteredCities[selectedIndex]
            defaults?.set(city.lat, forKey: "latitude")
            defaults?.set(city.lon, forKey: "longitude")
            defaults?.set("city", forKey: "locationMode")
            defaults?.set(city.c, forKey: "cityName")
            defaults?.set(city.cn, forKey: "countryName")
            defaults?.set(city.cc, forKey: "countryCode")
            
            var rName = city.c
            if let tz = city.tz, tz.contains("/") {
                rName = tz.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ") ?? city.c
            }
            defaults?.set(rName, forKey: "regionName")
            if let tz = city.tz { defaults?.set(tz, forKey: "timezone") }
            defaults?.synchronize()
            
            latField.stringValue = "\(city.lat)"
            lonField.stringValue = "\(city.lon)"
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let comboBox = obj.object as? NSComboBox, comboBox == citySearchBox else { return }
        hideError()
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
}
