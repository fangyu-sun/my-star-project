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
    let modeSegment = NSSegmentedControl(labels: ["Current Position", "City", "Manual"], trackingMode: .selectOne, target: nil, action: nil)
    
    let citySearchBox = NSComboBox()
    let inlineErrorLabel = NSTextField(labelWithString: "")
    
    let latField = NSTextField()
    let lonField = NSTextField()
    let findCurrentLocBtn = NSButton(title: "Find Current Location", target: nil, action: nil)
    
    let langPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let freqSlider = NSSlider(value: 1, minValue: 0, maxValue: 2, target: nil, action: nil)
    let freqLabel = NSTextField(labelWithString: "Normal (10s)")
    let glowSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 2.0, target: nil, action: nil)
    
    // Form State (Transaction Model)
    var formActiveMode: String = "currentPosition"
    
    var formCurrentLat: Double?
    var formCurrentLon: Double?
    var formCurrentCityName: String?
    
    var formCityLat: Double?
    var formCityLon: Double?
    var formCityCityName: String?
    var formCityCountryName: String?
    var formCityCountryCode: String?
    var formCityTimezone: String?
    
    var formManualLat: Double?
    var formManualLon: Double?
    
    var formLanguage: String = "en"
    var formDisplayFrequency: Int = 10
    var formBrightness: Double = 1.0
    var formDebug: Bool = false
    
    init() {
        defaults = ScreenSaverDefaults(forModuleWithName: defaultsModuleName)
        let windowRect = NSRect(x: 0, y: 0, width: 480, height: 380)
        let window = NSPanel(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "My Universe Settings"
        super.init(window: window)
        
        locationManager.delegate = self
        
        setupUI()
        loadCitiesDatabase()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        loadDefaultsToFormState()
        syncUIWithFormState()
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
        
        // Location Settings
        let locLabel = NSTextField(labelWithString: "Location Mode")
        locLabel.font = NSFont.boldSystemFont(ofSize: 14)
        mainStack.addArrangedSubview(locLabel)
        
        modeSegment.target = self
        modeSegment.action = #selector(modeChanged(_:))
        mainStack.addArrangedSubview(modeSegment)
        
        // Contextual UI Container
        let modeStack = NSStackView()
        modeStack.orientation = .vertical
        modeStack.alignment = .leading
        modeStack.spacing = 10
        mainStack.addArrangedSubview(modeStack)
        
        // 1. City UI
        let cityRow = NSStackView()
        cityRow.orientation = .horizontal
        cityRow.spacing = 10
        let cityLabel = NSTextField(labelWithString: "Search City:")
        citySearchBox.usesDataSource = true
        citySearchBox.dataSource = self
        citySearchBox.delegate = self
        citySearchBox.completes = true
        citySearchBox.widthAnchor.constraint(equalToConstant: 250).isActive = true
        citySearchBox.placeholderString = "Search e.g. London"
        cityRow.addArrangedSubview(cityLabel)
        cityRow.addArrangedSubview(citySearchBox)
        modeStack.addArrangedSubview(cityRow)
        
        // 2. Manual UI
        let coordsRow = NSStackView()
        coordsRow.orientation = .horizontal
        coordsRow.spacing = 10
        let latLabel = NSTextField(labelWithString: "Latitude:")
        latField.widthAnchor.constraint(equalToConstant: 75).isActive = true
        latField.delegate = self
        let lonLabel = NSTextField(labelWithString: "Longitude:")
        lonField.widthAnchor.constraint(equalToConstant: 75).isActive = true
        lonField.delegate = self
        coordsRow.addArrangedSubview(latLabel)
        coordsRow.addArrangedSubview(latField)
        coordsRow.addArrangedSubview(lonLabel)
        coordsRow.addArrangedSubview(lonField)
        modeStack.addArrangedSubview(coordsRow)
        
        // 3. Current Pos UI
        findCurrentLocBtn.target = self
        findCurrentLocBtn.action = #selector(findCurrentLocation)
        modeStack.addArrangedSubview(findCurrentLocBtn)
        
        // Inline Error
        inlineErrorLabel.textColor = .systemRed
        inlineErrorLabel.isEditable = false
        inlineErrorLabel.isSelectable = false
        inlineErrorLabel.isBordered = false
        inlineErrorLabel.backgroundColor = .clear
        inlineErrorLabel.font = NSFont.systemFont(ofSize: 11)
        inlineErrorLabel.isHidden = true
        mainStack.addArrangedSubview(inlineErrorLabel)
        
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.widthAnchor.constraint(equalToConstant: 440).isActive = true
        mainStack.addArrangedSubview(separator2)
        
        // Display Settings
        let displayLabel = NSTextField(labelWithString: "Display Settings")
        displayLabel.font = NSFont.boldSystemFont(ofSize: 14)
        mainStack.addArrangedSubview(displayLabel)
        
        // Lang Row
        let langRow = NSStackView()
        langRow.orientation = .horizontal
        langPopUp.addItems(withTitles: ["English", "简体中文", "繁體中文", "日本語"])
        langPopUp.target = self
        langPopUp.action = #selector(langChanged(_:))
        langRow.addArrangedSubview(NSTextField(labelWithString: "Language:"))
        langRow.addArrangedSubview(langPopUp)
        mainStack.addArrangedSubview(langRow)
        
        // Freq Row
        let freqRow = NSStackView()
        freqRow.orientation = .horizontal
        freqSlider.numberOfTickMarks = 3
        freqSlider.allowsTickMarkValuesOnly = true
        freqSlider.target = self
        freqSlider.action = #selector(freqChanged(_:))
        freqSlider.widthAnchor.constraint(equalToConstant: 100).isActive = true
        freqRow.addArrangedSubview(NSTextField(labelWithString: "Frequency:"))
        freqRow.addArrangedSubview(freqSlider)
        freqRow.addArrangedSubview(freqLabel)
        mainStack.addArrangedSubview(freqRow)
        
        // Glow Row
        let glowRow = NSStackView()
        glowRow.orientation = .horizontal
        glowSlider.target = self
        glowSlider.action = #selector(glowChanged(_:))
        glowSlider.widthAnchor.constraint(equalToConstant: 100).isActive = true
        glowRow.addArrangedSubview(NSTextField(labelWithString: "Text Glow:"))
        glowRow.addArrangedSubview(glowSlider)
        mainStack.addArrangedSubview(glowRow)
        
        // Bottom Buttons
        let bottomStack = NSStackView()
        bottomStack.orientation = .horizontal
        bottomStack.alignment = .centerY
        bottomStack.widthAnchor.constraint(equalToConstant: 440).isActive = true
        
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(savePressed))
        saveBtn.keyEquivalent = "\r"
        
        let btnContainer = NSStackView(views: [cancelBtn, saveBtn])
        btnContainer.orientation = .horizontal
        
        bottomStack.addView(NSView(), in: .leading) // spacer
        bottomStack.addView(btnContainer, in: .trailing)
        mainStack.addArrangedSubview(bottomStack)
    }
    
    // MARK: - Transaction Model (Form State)
    func loadDefaultsToFormState() {
        formActiveMode = defaults?.string(forKey: "activeMode") ?? "city"
        
        formCurrentLat = defaults?.object(forKey: "currentPosition_lat") as? Double
        formCurrentLon = defaults?.object(forKey: "currentPosition_lon") as? Double
        formCurrentCityName = defaults?.string(forKey: "currentPosition_cityName")
        
        formCityLat = defaults?.object(forKey: "city_lat") as? Double
        formCityLon = defaults?.object(forKey: "city_lon") as? Double
        formCityCityName = defaults?.string(forKey: "city_cityName")
        formCityCountryName = defaults?.string(forKey: "city_countryName")
        formCityCountryCode = defaults?.string(forKey: "city_countryCode")
        formCityTimezone = defaults?.string(forKey: "city_timezone")
        
        formManualLat = defaults?.object(forKey: "manual_lat") as? Double
        formManualLon = defaults?.object(forKey: "manual_lon") as? Double
        
        formLanguage = defaults?.string(forKey: "language") ?? "en"
        formDisplayFrequency = defaults?.integer(forKey: "displayFrequency") ?? 10
        if formDisplayFrequency == 0 { formDisplayFrequency = 10 }
        formBrightness = defaults?.double(forKey: "brightness") ?? 1.0
        if formBrightness == 0 { formBrightness = 1.0 }
        formDebug = defaults?.bool(forKey: "debug") ?? false
    }
    
    func syncUIWithFormState() {
        // Mode switch
        switch formActiveMode {
        case "currentPosition": modeSegment.selectedSegment = 0
        case "city": modeSegment.selectedSegment = 1
        case "manual": modeSegment.selectedSegment = 2
        default: modeSegment.selectedSegment = 1
        }
        
        // City Box
        if let cn = formCityCityName, !cn.isEmpty {
            citySearchBox.stringValue = cn
        } else {
            citySearchBox.stringValue = ""
        }
        
        // Manual Coords
        if let ml = formManualLat { latField.stringValue = "\(ml)" } else { latField.stringValue = "" }
        if let mn = formManualLon { lonField.stringValue = "\(mn)" } else { lonField.stringValue = "" }
        
        // Lang
        switch formLanguage {
        case "en": langPopUp.selectItem(at: 0)
        case "zh": langPopUp.selectItem(at: 1)
        case "zh-TW": langPopUp.selectItem(at: 2)
        case "ja": langPopUp.selectItem(at: 3)
        default: langPopUp.selectItem(at: 0)
        }
        
        // Freq
        if formDisplayFrequency <= 5 {
            freqSlider.integerValue = 2
            freqLabel.stringValue = "Fast (5s)"
        } else if formDisplayFrequency >= 30 {
            freqSlider.integerValue = 0
            freqLabel.stringValue = "Slow (30s)"
        } else {
            freqSlider.integerValue = 1
            freqLabel.stringValue = "Normal (10s)"
        }
        
        // Glow
        glowSlider.doubleValue = formBrightness
        
        updateContextualUI()
    }
    
    @objc func modeChanged(_ sender: NSSegmentedControl) {
        hideError()
        switch sender.selectedSegment {
        case 0: formActiveMode = "currentPosition"
        case 1: formActiveMode = "city"
        case 2: formActiveMode = "manual"
        default: formActiveMode = "city"
        }
        updateContextualUI()
    }
    
    func updateContextualUI() {
        findCurrentLocBtn.isEnabled = (formActiveMode == "currentPosition")
        citySearchBox.isEnabled = (formActiveMode == "city")
        latField.isEnabled = (formActiveMode == "manual")
        lonField.isEnabled = (formActiveMode == "manual")
    }
    
    @objc func langChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0: formLanguage = "en"
        case 1: formLanguage = "zh"
        case 2: formLanguage = "zh-TW"
        case 3: formLanguage = "ja"
        default: formLanguage = "en"
        }
    }
    
    @objc func freqChanged(_ sender: NSSlider) {
        switch sender.integerValue {
        case 0:
            formDisplayFrequency = 30
            freqLabel.stringValue = "Slow (30s)"
        case 1:
            formDisplayFrequency = 10
            freqLabel.stringValue = "Normal (10s)"
        case 2:
            formDisplayFrequency = 5
            freqLabel.stringValue = "Fast (5s)"
        default: break
        }
    }
    
    @objc func glowChanged(_ sender: NSSlider) {
        formBrightness = sender.doubleValue
    }
    
    // MARK: - Validation & Save
    @objc func savePressed() {
        hideError()
        
        // Validate based on mode
        if formActiveMode == "manual" {
            guard let lat = Double(latField.stringValue), let lon = Double(lonField.stringValue),
                  lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
                showInlineError("Invalid manual coordinates. Lat: -90~90, Lon: -180~180.")
                return
            }
            formManualLat = lat
            formManualLon = lon
        }
        
        if formActiveMode == "city" {
            if formCityLat == nil || formCityLon == nil {
                showInlineError("Please select a valid city from the search dropdown.")
                return
            }
        }
        
        if formActiveMode == "currentPosition" {
            let authStatus: CLAuthorizationStatus
            if #available(macOS 11.0, *) {
                authStatus = locationManager.authorizationStatus
            } else {
                authStatus = CLLocationManager.authorizationStatus()
            }
            
            let isAuthorized = (authStatus == .authorized || authStatus == .authorizedAlways)
            
            if !isAuthorized && formCurrentLat == nil {
                let alert = NSAlert()
                alert.messageText = "Missing Location Permission"
                alert.informativeText = "Current Position currently has no location permission. Use Find Current Location?"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Find Current Location")
                alert.addButton(withTitle: "Continue Anyway")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    findCurrentLocation()
                    return
                } else if response == .alertThirdButtonReturn {
                    return
                }
                // Second button (Continue Anyway) proceeds to save.
            }
        }
        
        // Write to UserDefaults
        defaults?.set(formActiveMode, forKey: "activeMode")
        
        if let clat = formCurrentLat { defaults?.set(clat, forKey: "currentPosition_lat") }
        if let clon = formCurrentLon { defaults?.set(clon, forKey: "currentPosition_lon") }
        if let cn = formCurrentCityName { defaults?.set(cn, forKey: "currentPosition_cityName") }
        
        if let citylat = formCityLat { defaults?.set(citylat, forKey: "city_lat") }
        if let citylon = formCityLon { defaults?.set(citylon, forKey: "city_lon") }
        if let cityname = formCityCityName { defaults?.set(cityname, forKey: "city_cityName") }
        if let citycname = formCityCountryName { defaults?.set(citycname, forKey: "city_countryName") }
        if let cityccode = formCityCountryCode { defaults?.set(cityccode, forKey: "city_countryCode") }
        if let citytz = formCityTimezone { defaults?.set(citytz, forKey: "city_timezone") }
        
        if let mlat = formManualLat { defaults?.set(mlat, forKey: "manual_lat") }
        if let mlon = formManualLon { defaults?.set(mlon, forKey: "manual_lon") }
        
        defaults?.set(formLanguage, forKey: "language")
        defaults?.set(formDisplayFrequency, forKey: "displayFrequency")
        defaults?.set(formBrightness, forKey: "brightness")
        defaults?.set(formDebug, forKey: "debug")
        
        defaults?.synchronize()
        
        if let win = window {
            win.sheetParent?.endSheet(win)
        }
    }
    
    @objc func cancelPressed() {
        if let win = window {
            win.sheetParent?.endSheet(win)
        }
    }
    
    // MARK: - CoreLocation
    @objc private func findCurrentLocation() {
        hideError()
        let authStatus: CLAuthorizationStatus
        if #available(macOS 11.0, *) {
            authStatus = locationManager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showInlineError("Could not get current location (Denied).")
            return
        }
        
        findCurrentLocBtn.title = "Locating..."
        findCurrentLocBtn.isEnabled = false
        
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.locationManager.stopUpdatingLocation()
            self?.handleLocationFailure(reason: "Could not get current location (Timeout).")
        }
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationTimer?.invalidate()
        findCurrentLocBtn.title = "Find Current Location"
        findCurrentLocBtn.isEnabled = true
        
        if let loc = locations.last {
            formCurrentLat = loc.coordinate.latitude
            formCurrentLon = loc.coordinate.longitude
            formCurrentCityName = "Current Location"
            showInlineError("Location acquired! Don't forget to click Save.") // Not an error, just feedback
            inlineErrorLabel.textColor = .systemGreen
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationTimer?.invalidate()
        handleLocationFailure(reason: "Could not get current location. Please check privacy settings.")
    }
    
    private func handleLocationFailure(reason: String) {
        findCurrentLocBtn.title = "Find Current Location"
        findCurrentLocBtn.isEnabled = true
        showInlineError(reason)
    }
    
    private func showInlineError(_ msg: String) {
        inlineErrorLabel.textColor = .systemRed
        inlineErrorLabel.stringValue = msg
        inlineErrorLabel.isHidden = false
    }
    
    private func hideError() {
        inlineErrorLabel.isHidden = true
    }
    
    // MARK: - Offline City Database
    private func loadCitiesDatabase() {
        guard let url = Bundle(for: type(of: self)).url(forResource: "cities", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            allCities = try JSONDecoder().decode([City].self, from: data)
            filteredCities = Array(allCities.prefix(20))
        } catch {}
    }
    
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
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        hideError()
        let selectedIndex = citySearchBox.indexOfSelectedItem
        if selectedIndex >= 0 && selectedIndex < filteredCities.count {
            let city = filteredCities[selectedIndex]
            formCityLat = city.lat
            formCityLon = city.lon
            formCityCityName = city.c
            formCityCountryName = city.cn
            formCityCountryCode = city.cc
            formCityTimezone = city.tz
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
                (city.alt?.contains(where: { $0.lowercased().hasPrefix(searchString) }) ?? false)
            }
            filteredCities = Array(matches.sorted(by: { $0.p > $1.p }).prefix(20))
        }
        comboBox.reloadData()
    }
}
