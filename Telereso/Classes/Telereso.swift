
import FirebaseRemoteConfig
import SwiftyJSON


internal let TAG = "Telereso"
internal let TAG_STRINGS = "\(TAG)_strings"
internal let TAG_DRAWABLES = "\(TAG)_drawable"
private let STRINGS = "strings"
private let DRAWABLE = "drawables"
private let SCALE_DRAWABLE_KEY = "\(DRAWABLE)" + "_" + "\(Int(UIScreen.main.scale))x"

public struct Telereso{
    @available(*, unavailable) private init() {}

    static private var isLogEnabled = true
    static private var isStringLogEnabled = false
    static private var isDrawableLogEnabled = false
    static private var _isRealTimeChangesEnabled = false
    static private var stringsMap = [String : [String : JSON]]()
    static private var drawablesMap = [String : [String : JSON]]()
    static private var currentLocal: String?
    static private var remoteConfigSettings: RemoteConfigSettings?
    static private var remoteConfig: RemoteConfig!

    static public func initialize(locale: String? = nil, completionHandler: (() -> Void)? = nil) {
        log("Initializing...")
        currentLocal = locale
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
                self.log("Fetched new data")
                self.initMaps()
            }
            completionHandler?()
        }
        initMaps()
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
        let value = getStringValue(local, key, defaultValue)
        logStrings("local:\(local) default:\(defaultValue ?? "") value:\(value)")
        if (value.isEmpty) {
            logStrings("\(key) was empty in \(getStringKey(local)) and \(STRINGS) and local strings",true)
            onResourceNotFound(key)
        }
        logStrings("*************************************************")
        return value
    }
    
    static public func getRemoteString(_ key:String,_ comment:String = "") -> String{
        return getRemoteStringOrDefault(getLocal(), key, NSLocalizedString(key, comment: comment))
    }
    
    static private func fetchResource(completionHandler: ((Bool) -> Void)? = nil) {
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
    
    static private func initMaps(){
        initStrings()
        initDrawables()
    }

    static private func initStrings() {
        let defaultString = remoteConfig.configValue(forKey: STRINGS).jsonValue
        var defaultJson :[String : JSON]
        
        if (defaultString == nil) {
            defaultJson = JSON.init(parseJSON:"{}").dictionary ?? [:]
            log("Your default local \(STRINGS) was not found in remote config", true)
        } else {
            log("Default local \(STRINGS) was setup")
            defaultJson = JSON(defaultString!).dictionary ?? [:]
        }
        stringsMap[STRINGS] = defaultJson
        
        let deviceLocal = getLocal()
        let local = getRemoteLocal(deviceLocal)
        stringsMap[getStringKey(deviceLocal)] = JSON.init(parseJSON:local).dictionary ?? [:]
    }
    
    static private func initDrawables() {
        let defaultString = remoteConfig.configValue(forKey: DRAWABLE).jsonValue
        var defaultJson :[String : JSON]

        if (defaultString == nil) {
            defaultJson = JSON.init(parseJSON:"{}").dictionary ?? [:]
            log("Your default local \(DRAWABLE) was not found in remote config", true)
        } else {
            log("Default local \(DRAWABLE) was setup")
            defaultJson = JSON(defaultString!).dictionary ?? [:]
        }
        drawablesMap[DRAWABLE] = defaultJson
        let drawableValue = getDrawableValue(SCALE_DRAWABLE_KEY)
        drawablesMap[SCALE_DRAWABLE_KEY] = JSON.init(parseJSON:drawableValue).dictionary ?? [:]
    }
    
    static private func getLocal() -> String{
        guard let locale = currentLocal else { return Bundle.main.preferredLocalizations.first ?? "en" }
        return locale
    }
    
    static private func getRemoteLocal(_ deviceLocal: String) -> String {
        var local = remoteConfig.configValue(forKey: getStringKey(deviceLocal)).stringValue ?? ""
        if (local.isEmpty) {
            let baseLocal = deviceLocal.split{$0 == "_"}[0].base
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
    
    static private func getDrawableValue(_ drawableKey: String) -> String {
        var drawableValue = remoteConfig.configValue(forKey: drawableKey).stringValue ?? ""
        if (drawableKey.isEmpty) {
            let baseDrawable = drawableKey.split{$0 == "_"}[0].base
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
        var value = stringsMap[localId]?[key]?.string ?? ""
        if (value.isEmpty) {
            logStrings("\(key) was not found in remote \(localId)", true)
            value = stringsMap[STRINGS]?[key]?.string ?? ""
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
        var url = drawablesMap[SCALE_DRAWABLE_KEY]?[key]?.string ?? ""
        if url.isEmpty {
            logDrawables("\(key) was not found in remote \(SCALE_DRAWABLE_KEY)", true)
            url = drawablesMap[DRAWABLE]?[key]?.string ?? ""
            if url.isEmpty {
                logDrawables("\(key) was not found in remote \(DRAWABLE)", true)
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
        return "\(DRAWABLE)_\(id)"
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

