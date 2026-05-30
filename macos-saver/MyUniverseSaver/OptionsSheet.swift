import Cocoa
import ScreenSaver
import CoreLocation
import WebKit

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

class OptionsWindowController: NSWindowController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate, CLLocationManagerDelegate, WKScriptMessageHandler {
    
    static let shared = OptionsWindowController()
    let defaultsModuleName = "com.fangyu.MyUniverseSaver"
    let defaults: ScreenSaverDefaults?
    
    // CoreLocation
    let locationManager = CLLocationManager()
    var locationTimer: Timer?
    
    // City Database
    var allCities: [City] = []
    var filteredCities: [City] = []
    
    // Live Preview Support
    let previewContainer = NSView()
    private var previewWebView: WKWebView?
    
    // Ultimate Fallback (Greenwich)
    private let fallbackLat: Double = 51.4779
    private let fallbackLon: Double = -0.0015
    private let fallbackCityName = "Greenwich"
    private let fallbackRegionName = "London"
    private let fallbackCountryName = "United Kingdom"
    private let fallbackCountryCode = "GB"
    private let fallbackTimezone = "Europe/London"
    
    // UI Elements
    let modeSegment = NSSegmentedControl(labels: ["Current Position", "City", "Manual"], trackingMode: .selectOne, target: nil, action: nil)
    
    let citySearchBox = NSComboBox()
    let inlineErrorLabel = NSTextField(labelWithString: "")
    
    let latField = NSTextField()
    let lonField = NSTextField()
    let findCurrentLocBtn = NSButton(title: "Find Current Location", target: nil, action: nil)
    
    // Containers for mode toggling
    let cityRow = NSStackView()
    let coordsRow = NSStackView()
    let currentPosRow = NSStackView()
    
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
        let windowRect = NSRect(x: 0, y: 0, width: 780, height: 450)
        let window = NSPanel(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "My Universe Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        
        setupUI()
        loadCitiesDatabase()
        
        loadDefaultsToFormState()
        syncUIWithFormState()
        
        updatePreview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let rootStack = NSStackView()
        rootStack.orientation = .horizontal
        rootStack.alignment = .top
        rootStack.spacing = 20
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootStack)
        
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        // Left Column (Live Preview, width 380)
        let leftStack = NSStackView()
        leftStack.orientation = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 12
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.widthAnchor.constraint(equalToConstant: 380).isActive = true
        
        let previewTitle = NSTextField(labelWithString: "Live Preview | 实时预览")
        previewTitle.font = NSFont.boldSystemFont(ofSize: 14)
        leftStack.addArrangedSubview(previewTitle)
        
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.wantsLayer = true
        previewContainer.layer?.backgroundColor = NSColor.black.cgColor
        previewContainer.layer?.cornerRadius = 8
        previewContainer.layer?.masksToBounds = true
        
        NSLayoutConstraint.activate([
            previewContainer.widthAnchor.constraint(equalToConstant: 380),
            previewContainer.heightAnchor.constraint(equalToConstant: 260)
        ])
        leftStack.addArrangedSubview(previewContainer)
        
        let previewDesc = NSTextField(labelWithString: "Adaptively visualizes the universe state according to current location, language, and brightness options.\n实时根据当前位置、语言及文本辉度，高保真模拟屏保渲染。")
        previewDesc.textColor = .secondaryLabelColor
        previewDesc.font = NSFont.systemFont(ofSize: 11)
        previewDesc.isEditable = false
        previewDesc.isSelectable = false
        previewDesc.isBordered = false
        previewDesc.backgroundColor = .clear
        leftStack.addArrangedSubview(previewDesc)
        
        rootStack.addArrangedSubview(leftStack)
        
        // Right Column (Settings Controls, width 340)
        let rightStack = NSStackView()
        rightStack.orientation = .vertical
        rightStack.alignment = .leading
        rightStack.spacing = 15
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.widthAnchor.constraint(equalToConstant: 340).isActive = true
        
        // Location Settings
        let locLabel = NSTextField(labelWithString: "Location Mode")
        locLabel.font = NSFont.boldSystemFont(ofSize: 14)
        rightStack.addArrangedSubview(locLabel)
        
        modeSegment.target = self
        modeSegment.action = #selector(modeChanged(_:))
        rightStack.addArrangedSubview(modeSegment)
        
        // Contextual UI Container
        let modeStack = NSStackView()
        modeStack.orientation = .vertical
        modeStack.alignment = .leading
        modeStack.spacing = 10
        rightStack.addArrangedSubview(modeStack)
        
        // 1. City UI
        cityRow.orientation = .horizontal
        cityRow.spacing = 10
        let cityLabel = NSTextField(labelWithString: "Search City:")
        citySearchBox.usesDataSource = true
        citySearchBox.dataSource = self
        citySearchBox.delegate = self
        citySearchBox.completes = true
        citySearchBox.widthAnchor.constraint(equalToConstant: 220).isActive = true
        citySearchBox.placeholderString = "Search e.g. London"
        cityRow.addArrangedSubview(cityLabel)
        cityRow.addArrangedSubview(citySearchBox)
        modeStack.addArrangedSubview(cityRow)
        
        // 2. Manual UI
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
        currentPosRow.orientation = .vertical
        currentPosRow.alignment = .leading
        currentPosRow.spacing = 5
        findCurrentLocBtn.target = self
        findCurrentLocBtn.action = #selector(findCurrentLocation)
        currentPosRow.addArrangedSubview(findCurrentLocBtn)
        
        let descLabel = NSTextField(labelWithString: "Uses last successful location. If unavailable, falls back to Greenwich.")
        descLabel.textColor = .secondaryLabelColor
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.isEditable = false
        descLabel.isSelectable = false
        descLabel.isBordered = false
        descLabel.backgroundColor = .clear
        currentPosRow.addArrangedSubview(descLabel)
        
        modeStack.addArrangedSubview(currentPosRow)
        
        // Inline Error
        inlineErrorLabel.textColor = .systemRed
        inlineErrorLabel.isEditable = false
        inlineErrorLabel.isSelectable = false
        inlineErrorLabel.isBordered = false
        inlineErrorLabel.backgroundColor = .clear
        inlineErrorLabel.font = NSFont.systemFont(ofSize: 11)
        inlineErrorLabel.isHidden = true
        rightStack.addArrangedSubview(inlineErrorLabel)
        
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.widthAnchor.constraint(equalToConstant: 340).isActive = true
        rightStack.addArrangedSubview(separator2)
        
        // Display Settings
        let displayLabel = NSTextField(labelWithString: "Display Settings")
        displayLabel.font = NSFont.boldSystemFont(ofSize: 14)
        rightStack.addArrangedSubview(displayLabel)
        
        // Lang Row
        let langRow = NSStackView()
        langRow.orientation = .horizontal
        langPopUp.addItems(withTitles: ["English", "简体中文", "繁體中文", "日本語"])
        langPopUp.target = self
        langPopUp.action = #selector(langChanged(_:))
        langRow.addArrangedSubview(NSTextField(labelWithString: "Language:"))
        langRow.addArrangedSubview(langPopUp)
        rightStack.addArrangedSubview(langRow)
        
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
        rightStack.addArrangedSubview(freqRow)
        
        // Glow Row
        let glowRow = NSStackView()
        glowRow.orientation = .horizontal
        glowSlider.target = self
        glowSlider.action = #selector(glowChanged(_:))
        glowSlider.widthAnchor.constraint(equalToConstant: 100).isActive = true
        glowRow.addArrangedSubview(NSTextField(labelWithString: "Text Glow:"))
        glowRow.addArrangedSubview(glowSlider)
        rightStack.addArrangedSubview(glowRow)
        
        // Bottom Buttons
        let bottomStack = NSStackView()
        bottomStack.orientation = .horizontal
        bottomStack.alignment = .centerY
        bottomStack.widthAnchor.constraint(equalToConstant: 340).isActive = true
        
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(savePressed))
        saveBtn.keyEquivalent = "\r"
        
        let btnContainer = NSStackView(views: [cancelBtn, saveBtn])
        btnContainer.orientation = .horizontal
        
        bottomStack.addView(NSView(), in: .leading) // spacer
        bottomStack.addView(btnContainer, in: .trailing)
        rightStack.addArrangedSubview(bottomStack)
        
        rootStack.addArrangedSubview(rightStack)
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
        updatePreview()
    }
    
    func updateContextualUI() {
        currentPosRow.isHidden = (formActiveMode != "currentPosition")
        cityRow.isHidden = (formActiveMode != "city")
        coordsRow.isHidden = (formActiveMode != "manual")
    }
    
    @objc func langChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0: formLanguage = "en"
        case 1: formLanguage = "zh"
        case 2: formLanguage = "zh-TW"
        case 3: formLanguage = "ja"
        default: formLanguage = "en"
        }
        updatePreview()
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
        updatePreview()
    }
    
    @objc func glowChanged(_ sender: NSSlider) {
        formBrightness = sender.doubleValue
        updatePreview()
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
                let searchString = citySearchBox.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !searchString.isEmpty {
                    let match = allCities.first { city in
                        city.c.lowercased() == searchString ||
                        (city.alt?.contains(where: { $0.lowercased() == searchString }) ?? false) ||
                        "\(city.c.lowercased()), \(city.cn.lowercased())" == searchString
                    } ?? allCities.first { city in
                        searchString.hasPrefix(city.c.lowercased()) ||
                        city.c.lowercased().hasPrefix(searchString)
                    }
                    if let foundCity = match {
                        formCityLat = foundCity.lat
                        formCityLon = foundCity.lon
                        formCityCityName = foundCity.c
                        formCityCountryName = foundCity.cn
                        formCityCountryCode = foundCity.cc
                        formCityTimezone = foundCity.tz
                        
                        // Update combo box with the resolved formatted string
                        citySearchBox.stringValue = "\(foundCity.c), \(foundCity.cn)"
                    }
                }
            }
            
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
            showInlineError("CoreLocation denied. Resolving location via GeoIP...")
            inlineErrorLabel.textColor = .systemOrange
            fetchIPGeolocation()
            return
        }
        
        findCurrentLocBtn.title = "Locating..."
        findCurrentLocBtn.isEnabled = false
        
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.locationManager.stopUpdatingLocation()
            self?.showInlineError("CoreLocation timed out. Resolving via GeoIP...")
            self?.inlineErrorLabel.textColor = .systemOrange
            self?.fetchIPGeolocation()
        }
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    private func fetchIPGeolocation() {
        guard let url = URL(string: "https://ipapi.co/json/") else {
            self.handleLocationFailure(reason: "Could not get current location (Invalid URL).")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.locationTimer?.invalidate()
                self?.findCurrentLocBtn.title = "Find Current Location"
                self?.findCurrentLocBtn.isEnabled = true
                
                guard let self = self else { return }
                
                if let error = error {
                    self.handleLocationFailure(reason: "Could not get current location (\(error.localizedDescription)).")
                    return
                }
                
                guard let data = data else {
                    self.handleLocationFailure(reason: "Could not get current location (No data).")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let lat = json["latitude"] as? Double,
                           let lon = json["longitude"] as? Double {
                            self.formCurrentLat = lat
                            self.formCurrentLon = lon
                            self.formCurrentCityName = json["city"] as? String ?? "Current Location"
                            
                            self.showInlineError("Location acquired via GeoIP! Click Save.")
                            self.inlineErrorLabel.textColor = .systemGreen
                            self.updatePreview()
                            return
                        }
                    }
                } catch {}
                
                self.handleLocationFailure(reason: "Could not get current location (Resolution failed).")
            }
        }
        task.resume()
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
            
            updatePreview()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationTimer?.invalidate()
        showInlineError("CoreLocation failed. Resolving location via GeoIP...")
        inlineErrorLabel.textColor = .systemOrange
        fetchIPGeolocation()
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
            
            updatePreview()
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if let comboBox = obj.object as? NSComboBox, comboBox == citySearchBox {
            hideError()
            let searchString = comboBox.stringValue.lowercased()
            
            // Prevent feedback re-filtering when city is selected
            if let selectedCityName = formCityCityName, let selectedCountryName = formCityCountryName,
               searchString == "\(selectedCityName), \(selectedCountryName)".lowercased() {
                return
            }
            
            // User typed something new. Reset selected city coordinates so savePressed() will force matching.
            formCityLat = nil
            formCityLon = nil
            formCityCityName = nil
            formCityCountryName = nil
            formCityCountryCode = nil
            formCityTimezone = nil
            
            let trimmedSearch = comboBox.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !trimmedSearch.isEmpty {
                let match = allCities.first { city in
                    city.c.lowercased() == trimmedSearch ||
                    "\(city.c.lowercased()), \(city.cn.lowercased())" == trimmedSearch
                }
                if let foundCity = match {
                    formCityLat = foundCity.lat
                    formCityLon = foundCity.lon
                    formCityCityName = foundCity.c
                    formCityCountryName = foundCity.cn
                    formCityCountryCode = foundCity.cc
                    formCityTimezone = foundCity.tz
                }
            }
            updatePreview()
            
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
            if filteredCities.count > 0 {
                let ax = NSAccessibility.unignoredDescendant(of: comboBox)
                if let axElement = ax as? NSAccessibilityElement {
                    axElement.accessibilitySetValue(true as CFBoolean, forAttribute: .expanded)
                }
            }
        } else if let textField = obj.object as? NSTextField, (textField == latField || textField == lonField) {
            // Update manual form variables if they are valid doubles
            if let lat = Double(latField.stringValue), lat >= -90 && lat <= 90 {
                formManualLat = lat
            }
            if let lon = Double(lonField.stringValue), lon >= -180 && lon <= 180 {
                formManualLon = lon
            }
            updatePreview()
        }
    }
    
    // ================= NEW: Live Preview Core Implementation =================
    private func updatePreview() {
        var finalLat = fallbackLat
        var finalLon = fallbackLon
        var finalCityName = fallbackCityName
        var finalRegionName = fallbackRegionName
        var finalCountryName = fallbackCountryName
        var finalCountryCode = fallbackCountryCode
        var finalTimezone = fallbackTimezone
        let finalUpdatedAt: Double = 0
        
        switch formActiveMode {
        case "currentPosition":
            if let lat = formCurrentLat, let lon = formCurrentLon {
                finalLat = lat
                finalLon = lon
                finalCityName = formCurrentCityName ?? "Current Position"
                finalRegionName = ""
                finalCountryName = ""
                finalCountryCode = ""
                finalTimezone = ""
            }
        case "city":
            if let lat = formCityLat, let lon = formCityLon {
                finalLat = lat
                finalLon = lon
                finalCityName = formCityCityName ?? fallbackCityName
                finalRegionName = ""
                finalCountryName = formCityCountryName ?? ""
                finalCountryCode = formCityCountryCode ?? ""
                finalTimezone = formCityTimezone ?? fallbackTimezone
            }
        case "manual":
            if let lat = Double(latField.stringValue), let lon = Double(lonField.stringValue),
               lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                finalLat = lat
                finalLon = lon
                finalCityName = "Manual Coordinates"
                finalRegionName = ""
                finalCountryName = ""
                finalCountryCode = ""
                finalTimezone = ""
            } else if let lat = formManualLat, let lon = formManualLon {
                finalLat = lat
                finalLon = lon
                finalCityName = "Manual Coordinates"
                finalRegionName = ""
                finalCountryName = ""
                finalCountryCode = ""
                finalTimezone = ""
            }
        default:
            break
        }
        
        let bundle = Bundle(for: type(of: self))
        let buildTimestamp = bundle.object(forInfoDictionaryKey: "MyUniverseBuildTimestamp") as? String ?? "Unknown"
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.defaultWebpagePreferences = prefs
        
        let scriptSource = """
        window.MY_UNIVERSE_CONFIG = {
            runtime: "screensaver",
            latitude: \(finalLat),
            longitude: \(finalLon),
            locationMode: "\(formActiveMode)",
            cityName: "\(finalCityName)",
            regionName: "\(finalRegionName)",
            countryName: "\(finalCountryName)",
            countryCode: "\(finalCountryCode)",
            timezone: "\(finalTimezone)",
            updatedAt: \(finalUpdatedAt),
            language: "\(formLanguage)",
            brightness: \(formBrightness),
            displayFrequency: \(formDisplayFrequency),
            debug: \(formDebug ? "true" : "false"),
            buildTimestamp: "\(buildTimestamp)"
        };
        """
        
        let bridgeScriptSource = """
        (function() {
            var origLog = console.log;
            var origError = console.error;

            console.log = function() {
                var args = Array.prototype.slice.call(arguments);
                var msg = args.map(function(arg) {
                    return (typeof arg === 'object') ? JSON.stringify(arg) : String(arg);
                }).join(' ');
                origLog.apply(console, arguments);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                    window.webkit.messageHandlers.consoleLog.postMessage(msg);
                }
            };

            console.error = function() {
                var args = Array.prototype.slice.call(arguments);
                var msg = args.map(function(arg) {
                    return (typeof arg === 'object') ? JSON.stringify(arg) : String(arg);
                }).join(' ');
                origError.apply(console, arguments);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleError) {
                    window.webkit.messageHandlers.consoleError.postMessage(msg);
                }
            };

            window.onerror = function(message, source, lineno, colno, error) {
                var errMsg = "[GLOBAL ERROR] " + message + " at " + source + ":" + lineno + ":" + colno;
                if (error && error.stack) {
                    errMsg += "\\nStack: " + error.stack;
                }
                console.error(errMsg);
            };

            window.addEventListener("unhandledrejection", function(e) {
                var reason = e.reason;
                var errMsg = "[PROMISE ERROR] " + (reason && reason.stack ? reason.stack : String(reason));
                console.error(errMsg);
            });
        })();
        """
        
        let bridgeScript = WKUserScript(source: bridgeScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        let configScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        
        let userContentController = WKUserContentController()
        userContentController.addUserScript(bridgeScript)
        userContentController.addUserScript(configScript)
        userContentController.add(WeakScriptMessageHandler(self), name: "consoleLog")
        userContentController.add(WeakScriptMessageHandler(self), name: "consoleError")
        webConfiguration.userContentController = userContentController
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove old WebView and unregister message handlers to prevent leaks / bad accesses
            if let oldWV = self.previewWebView {
                oldWV.configuration.userContentController.removeScriptMessageHandler(forName: "consoleLog")
                oldWV.configuration.userContentController.removeScriptMessageHandler(forName: "consoleError")
                oldWV.removeFromSuperview()
            }
            
            // Instantiate new WebView inside container with exact bounds (380x260) to avoid zero-bounds issues
            let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 380, height: 260), configuration: webConfiguration)
            wv.autoresizingMask = [.width, .height]
            
            if wv.responds(to: Selector(("setDrawsBackground:"))) {
                wv.setValue(false, forKey: "drawsBackground")
            }
            
            self.previewContainer.addSubview(wv)
            self.previewWebView = wv
            
            // Load offline HTML
            if let bundleURL = bundle.url(forResource: "index", withExtension: "html", subdirectory: "web") {
                let dirURL = bundleURL.deletingLastPathComponent()
                wv.loadFileURL(bundleURL, allowingReadAccessTo: dirURL)
            }
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "consoleLog" {
            if let bodyString = message.body as? String {
                print("[JS LOG] \(bodyString)")
                NSLog("[JS LOG] \(bodyString)")
            }
        } else if message.name == "consoleError" {
            if let bodyString = message.body as? String {
                print("[JS ERROR] \(bodyString)")
                NSLog("[JS ERROR] \(bodyString)")
            }
        }
    }
    
    deinit {
        previewWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "consoleLog")
        previewWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "consoleError")
        previewWebView?.removeFromSuperview()
        previewWebView = nil
    }
}

private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
