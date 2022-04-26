
import FirebaseRemoteConfig
import SwiftyJSON
import SDWebImage


let TAG = "Telereso"
let stringsKey: String = TGroup.strings.rawValue
let drawableKey: String = TGroup.drawable.rawValue + "_" + "\(Int(UIScreen.main.scale))x"

enum TGroup: String {
    case strings = "strings"
    case drawable = "drawables"
}

public struct Telereso{
    @available(*, unavailable) private init() {}

    static private var isLogEnabled = true
    static private var isStringLogEnabled = false
    static private var isDrawableLogEnabled = false
    static private var _isRealTimeChangesEnabled = false
    
    static private var stringsMap = [String : [String : JSON]]()
    static private var drawablesMap = [String : JSON]()
    static private var currentLocale: String = ""
    static private var currentStringKey: String { "\(stringsKey)_\(currentLocale)" }
    static private var remoteConfigSettings: RemoteConfigSettings?
    static private var remoteConfig: RemoteConfig!

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
        return self
    }

    static public func initialize(languageCode:String, completionHandler: (() -> Void)? = nil) {
        log("Initializing...")
        currentLocale = languageCode
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
            completionHandler?()
        }
        initMaps()
        log("Initialized!")
    }
    
    static private func initMaps() {
        initStrings()
        initDrawables()
    }
    
    static private func initStrings() {
        let defaultString = remoteConfig.configValue(forKey: currentStringKey).jsonValue
        var defaultJson :[String : JSON]

        if (defaultString == nil) {
            defaultJson = JSON.init(parseJSON:"{}").dictionary ?? [:]
            log("Your current local \(currentStringKey) was not found in remote config", true)
        } else {
            log("Current local \(currentStringKey) was setup")
            defaultJson = JSON(defaultString!).dictionary ?? [:]
        }
        stringsMap[currentStringKey] = defaultJson
    }
    
    static private func initDrawables() {
        let defaultString = remoteConfig.configValue(forKey: drawableKey).jsonValue
        var defaultJson :[String : JSON]

        if (defaultString == nil) {
            defaultJson = JSON.init(parseJSON:"{}").dictionary ?? [:]
            log("Your default local \(drawableKey) was not found in remote config", true)
        } else {
            log("Default local \(drawableKey) was setup")
            defaultJson = JSON(defaultString!).dictionary ?? [:]
        }
        drawablesMap = defaultJson
    }
    
    static public func getRemoteStringOrDefault(_ local: String,_ key: String,
                                                _ defaultValue: String? = nil) -> String {
        logStrings("******************** \(key) ********************")
        let value = getStringValue(local, key, defaultValue)
        logStrings("local:\(local) default:\(defaultValue ?? "") value:\(value)")
        if (value.isEmpty) {
            logStrings("\(key) was empty in \(getStringKey(local)) and \(stringsKey) and local strings",true)
            onResourceNotFound(key)
        }
        logStrings("*************************************************")
        return value
    }
    
    static public func getRemoteString(_ key:String, _ comment:String = "") -> String {
        return getRemoteStringOrDefault(currentLocale, key, NSLocalizedString(key, comment: comment))
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
    
    static private func getStringValue(_ local: String, _ key: String, _ defaultValue: String?) -> String {
        let localId = getStringKey(local)
        var value = stringsMap[localId]?[key]?.string ?? ""
        if (value.isEmpty) {
            logStrings("\(key) was not found in remote \(localId)", true)
            value = stringsMap[stringsKey]?[key]?.string ?? ""
            if (value.isEmpty) {
                logStrings("\(key) was not found in remote \(stringsKey)", true)
                value = defaultValue ?? ""
            } else {
                logStrings("\(key) was found in remote \(stringsKey)")
            }
        }
        return value
    }
    
    static fileprivate func getDrawableURLFor(key: String) -> URL? {
        guard let url = drawablesMap[key]?.string else { return nil }
        return URL(string: url)
    }
    
    static private func onResourceNotFound(_ key :String){}
    
    static internal func isRealTimeChangesEnabled() -> Bool {
        return _isRealTimeChangesEnabled
    }
    

    static private func getStringKey(_ id: String) -> String {
        return "\(stringsKey)_\(id)"
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
    
    static private func logDrawables(log: String, _ isWarning: Bool = false) {
        if (isDrawableLogEnabled){
            if (isWarning) {
                debugPrint("\(TAG):  \(log)")
            } else {
                debugPrint("\(TAG):  \(log)")
            }
        }
    }
}

extension String{
   public func remoteLocale() -> String {
        Telereso.getRemoteString(self)
    }
}

extension UIImageView {
    public func setRemoteImageWith(key: String) {
        guard let url = Telereso.getDrawableURLFor(key: key) else {
            self.image = UIImage(named:key)
            return
        }
        sd_setImage(
            with: url,
            placeholderImage: nil,
            options: [.highPriority, .avoidAutoSetImage, .fromCacheOnly]) { [weak self] (cachedImage, error, cacheType, url) in
                if let image = cachedImage, error == nil {
                    self?.image = image
                    return
                }
                self?.sd_setImage(with: url, placeholderImage: UIImage(named:key),
                                  options: [.highPriority, .scaleDownLargeImages])
            }
    }
}

extension UIButton {

    public func setRemoteImageWith(key: String, for state: UIControl.State) {
        guard let url = Telereso.getDrawableURLFor(key: key) else {
            self.setImage(UIImage(named:key), for: state)
            return
        }
        sd_setImage(with: url, for: state, placeholderImage: nil, options: [.highPriority, .avoidAutoSetImage, .fromCacheOnly]) { [weak self] cachedImage, error, cacheType, url in
            if let image = cachedImage, error == nil {
                self?.setImage(image, for: state)
                return
            }
            self?.sd_setImage(with: url, for: state, placeholderImage: UIImage(named:key), options: [.highPriority, .scaleDownLargeImages])
        }
    }

    public func setRemoteBackgroundImageWith(key: String, for state: UIControl.State) {
        guard let url = Telereso.getDrawableURLFor(key: key) else {
            self.setBackgroundImage(UIImage(named:key), for: state)
            return
        }
        sd_setBackgroundImage(with: url, for: state, placeholderImage: nil, options: [.highPriority, .avoidAutoSetImage, .fromCacheOnly]) { [weak self] cachedImage, error, cacheType, url in
            if let image = cachedImage, error == nil {
                self?.setImage(image, for: state)
                self?.setBackgroundImage(image, for: state)
                return
            }
            self?.sd_setBackgroundImage(with: url, for: state, placeholderImage: UIImage(named:key), options: [.highPriority, .scaleDownLargeImages])
        }
    }
}
