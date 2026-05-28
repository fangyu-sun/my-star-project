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
    var locationTimer: Timer?
    
    // City Database
    var allCities: [City] = []
    var filteredCities: [City] = []
    
    // UI Elements
    let statusLabel = NSTextField(labelWithString: "Current Location:\nNot set.")
    
    let citySearchBox = NSComboBox()
    let currentLocationBtn = NSButton(title: "Use Current Location", target: nil, action: nil)
    
    let latField = NSTextField()
    let lonField = NSTextField()
    let saveManualBtn = NSButton(title: "Save Coordinates", target: nil, action: nil)
    
    let langPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let freqSlider = NSSlider()
    let freqLabel = NSTextField(labelWithString: "10s")
    
    init() {
        let windowRect = NSRect(x: 0, y: 0, width: 480, height: 380)
        let window = NSPanel(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "My Universe Settings"
        super.init(window: window)
        
        locationManager.delegate = self
        
        migrateLegacyDefaults()
        setupUI()
        loadCitiesDatabase()
        updateStatusLabel()
        loadDisplayDefaults()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Legacy Migration
    private func migrateLegacyDefaults() {
        let lat = defaults?.double(forKey: "latitude") ?? 0.0
        let lon = defaults?.double(forKey: "longitude") ?? 0.0
        let mode = defaults?.string(forKey: "locationMode")
        
        // If it's an uninitialized state or the old 0.0 bug, migrate to strict Perth defaults
        if (lat == 0.0 && lon == 0.0) || mode == nil {
            defaults?.set(-31.9523, forKey: "latitude")
            defaults?.set(115.8613, forKey: "longitude")
            defaults?.set("default", forKey: "locationMode")
            defaults?.set("Perth", forKey: "cityName")
            defaults?.set("Western Australia", forKey: "regionName")
            defaults?.set("Australia", forKey: "countryName")
            defaults?.set("AU", forKey: "countryCode")
            defaults?.set("Australia/Perth", forKey: "timezone")
            defaults?.synchronize()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        // --- Status Area ---
        statusLabel.isEditable = false
        statusLabel.isSelectable = true
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        mainStack.addArrangedSubview(statusLabel)
        
        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.widthAnchor.constraint(equalToConstant: 440).isActive = true
        mainStack.addArrangedSubview(separator1)
        
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
        citySearchBox.placeholderString = "Search e.g. Perth"
        
        currentLocationBtn.target = self
        currentLocationBtn.action = #selector(useCurrentLocation)
        
        cityRow.addArrangedSubview(cityLabel)
        cityRow.addArrangedSubview(citySearchBox)
        cityRow.addArrangedSubview(currentLocationBtn)
        mainStack.addArrangedSubview(cityRow)
        
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
    private func updateStatusLabel() {
        let mode = defaults?.string(forKey: "locationMode") ?? "default"
        let lat = defaults?.double(forKey: "latitude") ?? -31.9523
        let lon = defaults?.double(forKey: "longitude") ?? 115.8613
        let cName = defaults?.string(forKey: "cityName") ?? "Perth"
        let rName = defaults?.string(forKey: "regionName") ?? "Western Australia"
        let cnName = defaults?.string(forKey: "countryName") ?? "Australia"
        
        var header = "Current Location:"
        if mode == "default" {
            header = "Current Location:\nNot set. Using default:"
        }
        
        var locDisplay = ""
        if mode == "city" || mode == "default" {
            locDisplay = "\(cName), \(rName), \(cnName)\nLatitude: \(lat)\nLongitude: \(lon)\nSource: \(mode.capitalized)"
        } else if mode == "currentLocation" {
            locDisplay = "Current Location (Device)\nLatitude: \(lat)\nLongitude: \(lon)\nSource: CoreLocation"
        } else {
            locDisplay = "Manual Coordinates\nLatitude: \(lat)\nLongitude: \(lon)\nSource: Manual"
        }
        
        statusLabel.stringValue = "\(header)\n\(locDisplay)"
        
        latField.stringValue = "\(lat)"
        lonField.stringValue = "\(lon)"
    }
    
    private func loadDisplayDefaults() {
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
        if let lat = Double(latField.stringValue), let lon = Double(lonField.stringValue) {
            if lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                if lat == 0.0 && lon == 0.0 {
                    showAlert("Warning", "0.0, 0.0 is generally an invalid ocean coordinate. Please enter valid coordinates.")
                    return
                }
                defaults?.set(lat, forKey: "latitude")
                defaults?.set(lon, forKey: "longitude")
                defaults?.set("manual", forKey: "locationMode")
                defaults?.set("Manual Coordinates", forKey: "cityName")
                defaults?.synchronize()
                updateStatusLabel()
                citySearchBox.stringValue = ""
            } else {
                showAlert("Invalid Coordinates", "Latitude must be between -90 and 90, Longitude between -180 and 180.")
            }
        } else {
            showAlert("Invalid Input", "Please enter valid numeric coordinates.")
        }
    }
    
    // MARK: - CoreLocation
    @objc private func useCurrentLocation() {
        let authStatus: CLAuthorizationStatus
        if #available(macOS 11.0, *) {
            authStatus = locationManager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showAlert("Location Denied", "Could not get current location. Permission is denied or restricted. Please search a city or enter coordinates manually.")
            return
        }
        
        currentLocationBtn.title = "Locating..."
        currentLocationBtn.isEnabled = false
        
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.locationManager.stopUpdatingLocation()
            self?.handleLocationFailure(reason: "Could not get current location (Timeout). Please search a city or enter coordinates manually.")
        }
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationTimer?.invalidate()
        currentLocationBtn.title = "Use Current Location"
        currentLocationBtn.isEnabled = true
        
        if let loc = locations.last {
            defaults?.set(loc.coordinate.latitude, forKey: "latitude")
            defaults?.set(loc.coordinate.longitude, forKey: "longitude")
            defaults?.set("currentLocation", forKey: "locationMode")
            defaults?.set("Current Location", forKey: "cityName")
            defaults?.set(Date().timeIntervalSince1970, forKey: "locationUpdatedAt")
            defaults?.synchronize()
            updateStatusLabel()
            citySearchBox.stringValue = ""
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationTimer?.invalidate()
        handleLocationFailure(reason: "Could not get current location. Please search a city or enter coordinates manually.")
    }
    
    private func handleLocationFailure(reason: String) {
        currentLocationBtn.title = "Use Current Location"
        currentLocationBtn.isEnabled = true
        showAlert("Location Error", reason)
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
            updateStatusLabel()
        }
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
