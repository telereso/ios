
import FirebaseRemoteConfig
import SwiftyJSON


internal let TAG = "Telereso"
internal let TAG_STRINGS = "\(TAG)_strings"
internal let TAG_DRAWABLES = "\(TAG)_drawable"
private let STRINGS = "strings"
private let DRAWABLES = "drawables"
private let SCALE_DRAWABLE_KEY = "\(DRAWABLES)" + "_" + "\(Int(UIScreen.main.scale))x"

public struct Telereso{
    @available(*, unavailable) private init() {}

    static private var isLogEnabled = true
    static private var isStringLogEnabled = false
    static private var isDrawableLogEnabled = false
    static private var _isRealTimeChangesEnabled = false
    static private let stringsMapQueue: DispatchQueue = DispatchQueue(label: "teleresoStringsMapQueue", attributes: .concurrent)
    static private var _stringsMap = [String : [String : JSON]]()
    static private var stringsMap: [String : [String : JSON]] {
        get {
            stringsMapQueue.sync { _stringsMap }
        }
        set {
            stringsMapQueue.async(flags: .barrier) {
                _stringsMap = newValue
            }
        }
    }
    static private let drawablesMapQueue: DispatchQueue = DispatchQueue(label: "teleresoDrawablesMapQueue", attributes: .concurrent)
    static private var _drawablesMap = [String : [String : JSON]]()
    static private var drawablesMap: [String : [String : JSON]] {
        get {
            drawablesMapQueue.sync { _drawablesMap }
        }
        set {
            drawablesMapQueue.async(flags: .barrier) {
                _drawablesMap = newValue
            }
        }
    }

    static private var currentLocal: String?
    static private var remoteConfigSettings: RemoteConfigSettings?
    static private var remoteConfig: RemoteConfig!

    static public func initialize(locale: String? = nil,
                                  waitFetch: Bool = false,
                                  completionHandler: (() -> Void)? = nil) {
        log("Initializing...")
        currentLocal = locale?.lowercased().replacingOccurrences(of: "-", with: "_")
        remoteConfig = RemoteConfig.remoteConfig()
        var settings = remoteConfigSettings
        if(settings == nil){
            let s = RemoteConfigSettings()
            if(_isRealTimeChangesEnabled){
                s.minimumFetchInterval = 0
            }
            settings = s
        }
        remoteConfig.configSettings = settings!
        fetchResource(){ (shouldUpdate) -> Void in
            if(shouldUpdate){
                self.initMaps()
                self.log("Fetched new data")
            }
            if waitFetch {
                completionHandler?()
            }
        }
        self.remoteConfig.activate { changed, error in
            initMaps()
            if !waitFetch {
                completionHandler?()
            }
        }
        log("Initialized!")
    }
    
    static public func setRemoteConfigSettings(_ remoteConfigSettings: RemoteConfigSettings) -> Telereso.Type {
        self.remoteConfigSettings = remoteConfigSettings;
        return self
    }
    
    static public func enableStringLog() -> Telereso.Type {
        isStringLogEnabled = true
        return self
    }
    
    static public func enableDrawableLog() -> Telereso.Type {
        isDrawableLogEnabled = true
        return self
    }
    
    static public func disableLog() -> Telereso.Type {
        isLogEnabled = false
        return self
    }
    
    static public func enableRealTimeChanges() -> Telereso.Type {
        _isRealTimeChangesEnabled = true
        subscriptToChanges()
        return self
    }
    
    static public func getRemoteStringOrDefault(_ local: String,_ key: String,_ defaultValue: String? = nil) -> String {
        logStrings("******************** \(key) ********************")
        var value = getStringValue(local, key, defaultValue)
        logStrings("local:\(local) default:\(defaultValue ?? "") value:\(value)")
        if (value.isEmpty) {
            logStrings("\(key) was empty in \(getStringKey(local)) and \(STRINGS) and local strings",true)
            onResourceNotFound(key)
        } else {
            value = value.replacingOccurrences(of: "%s", with: "%@")
        }
        logStrings("*************************************************")
        return value
    }
    
    static public func getRemoteString(_ key: String,_ comment:String = "") -> String {
        return getRemoteStringOrDefault(getLocal(), key, getDefaultValue(key))
    }

    static func getDefaultValue(_ key: String) -> String {
        var expected = NSLocalizedString(key, comment: "")
        if expected != key {
            return expected
        }
        if let path = Bundle.main.path(forResource: "Base", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            expected = NSLocalizedString(key, bundle: bundle, comment: "")
            if expected != key {
                return expected
            }
        }
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        return expected
    }
    
    static public func getRemoteString(_ key: String,_ comment:String = "", args: [CVarArg]) -> String {
        return Self.getRemoteString(key, comment).stringWithParams(args)
    }
    
    static private func fetchResource(completionHandler: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            remoteConfig.fetch { (status, error) -> Void in
                if status == .success {
                    self.log("Config fetched!")
                    self.remoteConfig.activate { changed, error in
                        completionHandler?(changed)
                    }
                } else {
                    completionHandler?(false)
                    self.log("Config not fetched")
                    self.log("Error: \(error?.localizedDescription ?? "No error available.")")
                }
            }
        }
    }
    
    static private func initMaps(){
        initStrings()
        initDrawables()
    }

    static private func initStrings() {
        let defaultStrings = remoteConfig.configValue(forKey: STRINGS).jsonValue
        var defaultJson :[String : JSON]
        
        if (defaultStrings == nil) {
            defaultJson = JSON.init(parseJSON:"{}").dictionary ?? [:]
            log("Your default local \(STRINGS) was not found in remote config", true)
        } else {
            log("Default local \(STRINGS) was setup")
            defaultJson = JSON(defaultStrings!).dictionary ?? [:]
        }
        stringsMap[STRINGS] = defaultJson
        
        let deviceLocal = getLocal()
        let local = getRemoteLocal(deviceLocal)
        stringsMap[getStringKey(deviceLocal)] = JSON.init(parseJSON:local).dictionary ?? [:]
    }
    
    static private func initDrawables() {
        let defaultDrawables = remoteConfig.configValue(forKey: DRAWABLES).jsonValue
        var defaultJson :[String : JSON]

        if (defaultDrawables == nil) {
            defaultJson = JSON.init(parseJSON:"{}").dictionary ?? [:]
            log("Your default local \(DRAWABLES) was not found in remote config", true)
        } else {
            log("Default local \(DRAWABLES) was setup")
            defaultJson = JSON(defaultDrawables!).dictionary ?? [:]
        }
        drawablesMap[DRAWABLES] = defaultJson
        let drawableValue = getRemoteDrawables(SCALE_DRAWABLE_KEY)
        drawablesMap[SCALE_DRAWABLE_KEY] = JSON.init(parseJSON:drawableValue).dictionary ?? [:]
    }
    
    static private func getLocal() -> String {
        guard let locale = currentLocal else { return Bundle.main.preferredLocalizations.first ?? "en" }
        return locale
    }
    
    static private func getRemoteLocal(_ deviceLocal: String) -> String {
        var local = remoteConfig.configValue(forKey: getStringKey(deviceLocal)).stringValue ?? ""
        if (local.isEmpty) {
            let baseLocal = deviceLocal.split{$0 == "_"}.first.map(String.init) ?? ""
            log("The app local \(deviceLocal) was not found in remote config will try \(baseLocal)")
            let key = remoteConfig.keys(withPrefix: getStringKey(baseLocal)).first
            if (key == nil) {
                log("\(baseLocal) was not found as well")
            } else {
                if (key!.contains("off")){
                    log("\(baseLocal) was found but it was turned off, remove _off suffix to enable it")
                } else {
                    local = remoteConfig.configValue(forKey: key).stringValue ?? ""
                }
            }
        }
        if (local.isEmpty) {
            local = "{}"
            log("The app local \(deviceLocal) was not found in remote config", true)
        } else {
            log("device local \(deviceLocal) was setup")
        }
        return local
    }
    
    static private func getRemoteDrawables(_ drawableKey: String) -> String {
        var drawableValue = remoteConfig.configValue(forKey: drawableKey).stringValue ?? ""
        if (drawableValue.isEmpty) {
            let baseDrawable = drawableKey.split{$0 == "_"}.first.map(String.init) ?? ""
            log("The app drawable \(drawableKey) was not found in remote config will try \(baseDrawable)")
            let key = remoteConfig.keys(withPrefix: getStringKey(baseDrawable)).first
            if (key == nil) {
                log("\(baseDrawable) was not found as well")
            } else {
                if (key!.contains("off")){
                    log("\(baseDrawable) was found but it was turned off, remove _off suffix to enable it")
                } else {
                    drawableValue = remoteConfig.configValue(forKey: key).stringValue ?? ""
                }
            }
        }
        if (drawableValue.isEmpty) {
            drawableValue = "{}"
            log("The app drawable \(drawableKey) was not found in remote config", true)
        } else {
            log("device drawable \(drawableKey) was setup")
        }
        return drawableValue
    }
    
    static private func getStringValue(_ local: String, _ key: String, _ defaultValue: String?) -> String {
        let localId = getStringKey(local)
        var value = stringsMap[localId]?[key]?.stringValue ?? ""
        if (value.isEmpty) {
            logStrings("\(key) was not found in remote \(localId)", true)
            value = stringsMap[STRINGS]?[key]?.stringValue ?? ""
            if (value.isEmpty) {
                logStrings("\(key) was not found in remote \(STRINGS)", true)
                value = defaultValue ?? ""
            } else {
                logStrings("\(key) was found in remote \(STRINGS)")
            }
        }
        return value
    }
    
    static internal func getRemoteDrawable(key: String) -> URL? {
        var url = drawablesMap[SCALE_DRAWABLE_KEY]?[key]?.stringValue ?? ""
        if url.isEmpty {
            logDrawables("\(key) was not found in remote \(SCALE_DRAWABLE_KEY)", true)
            url = drawablesMap[DRAWABLES]?[key]?.stringValue ?? ""
            if url.isEmpty {
                logDrawables("\(key) was not found in remote \(DRAWABLES)", true)
            }
        }
        guard !url.isEmpty else { return nil }
        return URL(string: url)
    }
    
    static private func onResourceNotFound(_ key :String){}
    
    static private func subscriptToChanges() {}
    
    static internal func isRealTimeChangesEnabled() -> Bool {
        return _isRealTimeChangesEnabled
    }
    
    static private func getStringKey(_ id: String) -> String {
        return "\(STRINGS)_\(id)"
    }
    
    static private func getDrawableKey(_ id: String) -> String {
        return "\(DRAWABLES)_\(id)"
    }
    
    static private func log(_ log: String, _ isWarning: Bool = false) {
        if (isLogEnabled){
            if (isWarning) {
                debugPrint("\(TAG):  \(log)")
            } else {
                debugPrint("\(TAG):  \(log)")
            }
        }
    }
    
    static private func logStrings(_ log: String, _ isWarning: Bool = false) {
        if (isStringLogEnabled){
            if (isWarning) {
                debugPrint("\(TAG):  \(log)")
            } else {
                debugPrint("\(TAG):  \(log)")
            }
        }
    }
    
    static private func logDrawables(_ log: String, _ isWarning: Bool = false) {
        if (isDrawableLogEnabled){
            if (isWarning) {
                debugPrint("\(TAG):  \(log)")
            } else {
                debugPrint("\(TAG):  \(log)")
            }
        }
    }
}

