//
//  CJSkinSwift.swift
//  CJSkinSwift
//
//  Created by 练炽金 on 2021/8/16.
//

import UIKit
import SSZipArchive

/// 皮肤包配置plist文件固定名称（CJSkin.plist）
public private(set) var CJ_SKIN_PLIST_NAME: String      = "CJSkin"
/// 默认皮肤包名（default）
public private(set) var CJ_SKIN_DEFAULT_NAME: String    = "default"

private var SkinUISetUpAddNotificationKey: Void?
private var SkinUISetUpKey: Void?
private let CJSkinCurrentSkinName: String   = "CJSkinCurrentSkinName"
private let CJSkinPlistPath: String         = "CJSkinPlistPath"
private let CJSkinCurrentVersion: NSString  = "CJSkinCurrentVersion"
private var kSkinSandboxPlistPath: String?
private let CJSkinSandboxPlistPath: String! = {
    if kSkinSandboxPlistPath == nil {
        kSkinSandboxPlistPath = "\(SkinCachePath("",true))/\(CJSkinInfoHistoryName).plist"
    }
    return kSkinSandboxPlistPath
}()
private let CJSkinUpdateNotification: String = "CJ.skin.update.notification"

fileprivate var CJSKinlogEnable: Bool = true

internal func SkinLog<T>(_ message : T, file : String = #file, lineNumber : Int = #line) {
#if DEBUG
    if true == CJSKinlogEnable {
        let fileName = (file as NSString).lastPathComponent
        print("CJSkin [\(fileName) line:\(lineNumber)] \(message)")
    }
#endif
}

public enum CJSkinError: Error, LocalizedError {
    case CJSkinNameIsNull
    case CJSkinInfoUpdateFail
    case CJSkinNameNotExists
    case CJSkinRemoveDefaultError
    case CJSkinClearNotCacheError
    case CJSkinCreateDirectoryError
    case CJSkinUnzipError
    case CJSkinZipIsNullError
    case CJSkinZipWithoutSkinPlistError
    case CJSkinZipUpdateError
    
    public var errorDescription: String? {
        switch self {
            case .CJSkinNameIsNull:
                return "皮肤包名为空"
            case .CJSkinInfoUpdateFail:
                return "皮肤包配置信息CJSkin.plist更新出错"
            case .CJSkinNameNotExists:
                return "皮肤包不存在"
            case .CJSkinRemoveDefaultError:
                return "禁止删除默认皮肤包"
            case .CJSkinClearNotCacheError:
                return "删除缓存不存在"
            case .CJSkinCreateDirectoryError:
                return "创建缓存路径错误"
            case .CJSkinUnzipError:
                return "皮肤压缩包解压失败"
            case .CJSkinZipIsNullError:
                return "皮肤压缩包资源为空"
            case .CJSkinZipWithoutSkinPlistError:
                return "皮肤压缩包内缺失配置描述文件 CJSkin.plist"
            case .CJSkinZipUpdateError:
                return "皮肤压缩包资源更新失败"
        }
    }
}

/// 设置换肤UI刷新
public typealias SkinUISetUpBlock = (_ weakSelf: NSObject)->Void
public extension NSObject {
    private var addUISetUPNotification: Bool! {
        get {
            let addNotification = objc_getAssociatedObject(self, &SkinUISetUpAddNotificationKey) ?? false
            return (addNotification as! Bool)
        }
        set {
            objc_setAssociatedObject(self, &SkinUISetUpAddNotificationKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    /// 设置换肤UI刷新
    var refreshSkin: SkinUISetUpBlock {
        get {
            var setUp: SkinUISetUpBlock?
            if objc_getAssociatedObject(self, &SkinUISetUpKey) != nil {
                setUp = objc_getAssociatedObject(self, &SkinUISetUpKey) as? SkinUISetUpBlock
            }
            return setUp!
        }
        set {
            objc_setAssociatedObject(self, &SkinUISetUpKey, newValue, .OBJC_ASSOCIATION_COPY)
            if false == self.addUISetUPNotification {
                // iOS9.0之后，使用 addObserver(_:selector:name:object:) 方式注册的通知，无需再在dealloc/deinit方法中主动移除通知观察者了
                //详情见https://developer.apple.com/documentation/foundation/notificationcenter/1413994-removeobserver
                NotificationCenter.default.addObserver(self, selector: #selector(changeSkin), name: Notification.Name(CJSkinUpdateNotification), object: nil)
                self.addUISetUPNotification = true
            }
            changeSkin()
        }
    }
    
    @objc private func changeSkin(){
        weak var weakSelf = self
        self.refreshSkin(weakSelf!)
    }
}

/// 换肤相关操作完成回调
public typealias SkinActionCompletion = (_ result: Bool, _ msg: String)->Void

/// CJSkin换肤，支持内置皮肤切换以及在线皮肤更新
/// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/// 换肤资源管理说明：
/// 1、项目主工程内必须包含 CJSkin.plist，用于配置管理皮肤包说明
/// CJSkin.plist = {
///     "default": {
///         "Color": {
///             "color1" : "0xFFFFFF"
///         },
///         "Image": {
///             "image1" : "top.png",
///             "image2" : "https://www.xxx.png"
///         },
///         "Font": {
///             "font1" : {
///                 "Name" : "",
///                 "Size" : "16"
///             }
///         }
///     },
/// }
/// 2、内置不同皮肤包的图片资源放置在 skin.bundle 中，其中skin表示皮肤包名要与CJSkin.plist中的配置说明相同
/// 3、在线皮肤压缩包下载说明见 CJSkinSwift.downloadSkinZip() 注释说明
/// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
public class CJSkinSwift: NSObject {
    /// 获取默认皮肤包名
    @discardableResult
    static public func defaultSkinName()-> String {
        return CJSkinSwift.manager.defaultSkinName!
    }
    private var defaultSkinName: String?
    
    /// 获取默认皮肤包信息
    @discardableResult
    static public func defaultSkinInfo()-> NSDictionary {
        return CJSkinSwift.manager.defaultSkinInfo!
    }
    private var defaultSkinInfo: NSDictionary?
    
    /// 获取当前皮肤包名
    @discardableResult
    static public func skinName()-> String {
        return CJSkinSwift.manager.skinName!
    }
    private var skinName: String?
    
    /// 获取当前皮肤包信息
    @discardableResult
    static public func skinInfo()-> NSDictionary {
        return CJSkinSwift.manager.skinInfo!
    }
    private var skinInfo: NSDictionary?
    
    /// 获取所有皮肤配置信息的PlistInfo信息
    @discardableResult
    static public func skinPlistInfo() -> NSDictionary! {
        var info: NSMutableDictionary? = NSMutableDictionary.init(contentsOfFile: CJSkinSandboxPlistPath)
        if info == nil || info!.allKeys.count == 0 {
            let path: String = Bundle.main.path(forResource:CJ_SKIN_PLIST_NAME, ofType: "plist") ?? ""
            info = NSMutableDictionary.init(contentsOfFile: path) ?? nil
            assert((info != nil), " CJSkin.plist 皮肤配置读取失败，请检查项目中是否是包含该配置文件")
        }
        //返回信息中去除当前版本信息
        info?.removeObject(forKey: CJSkinCurrentVersion)
        return info
    }
    
    /// 皮肤资源为网络图片，图片下载成功后对应的图片内存缓存
    static internal func imageCache()-> NSCache<NSString, UIImage>! {
        return CJSkinSwift.manager.imageCache
    }
    private let imageCache: NSCache<NSString, UIImage> = NSCache<NSString, UIImage>.init()
    
    fileprivate static let manager = CJSkinSwift()
    private override init() {
        super.init()
        self._reloadPlistInfoFromBundleWithSkinVersion()
        self._readSkinInfo()
        self.imageCache.countLimit = 50
    }
    
    private func _reloadPlistInfoFromBundleWithSkinVersion() {
        let infoDictionary = Bundle.main.infoDictionary
        var appVersion: String {
            if let version = infoDictionary!["CFBundleShortVersionString"] as? String {
                return version
            }
            return "1.0.0"
        }
        if !FileManager.default.fileExists(atPath: CJSkinSandboxPlistPath!) {
            self._updateSkinSandboxPlistInfo(appVersion: appVersion, oldSkinHistoryInfo:nil)
        }else{
            let oldSkinHistoryInfo: NSDictionary = NSDictionary.init(contentsOfFile: CJSkinSandboxPlistPath)!
            let oldVersion: String = oldSkinHistoryInfo[CJSkinCurrentVersion] as! String
            if appVersion.compare(oldVersion, options: .numeric, range: nil, locale: nil) == .orderedDescending{
                self._updateSkinSandboxPlistInfo(appVersion: appVersion, oldSkinHistoryInfo:oldSkinHistoryInfo)
            }
        }
    }
    private func _updateSkinSandboxPlistInfo(appVersion:String, oldSkinHistoryInfo:NSDictionary?) {
        let info: NSMutableDictionary = NSMutableDictionary.init()
        if oldSkinHistoryInfo != nil {
            info.addEntries(from: oldSkinHistoryInfo as! [AnyHashable : Any])
        }
        let path: String = Bundle.main.path(forResource:CJ_SKIN_PLIST_NAME, ofType: "plist") ?? ""
        let bundleInfo: NSMutableDictionary? = NSMutableDictionary.init(contentsOfFile: path) ?? nil
        assert((bundleInfo != nil), " CJSkin.plist 皮肤配置读取失败，请检查项目中是否是包含该配置文件")
        bundleInfo?.setObject(appVersion, forKey: CJSkinCurrentVersion)
        info.addEntries(from: bundleInfo as! [AnyHashable : Any])
        info.write(toFile: CJSkinSandboxPlistPath, atomically: true)
    }
    
    private func _readSkinInfo() {
        self.defaultSkinName = CJ_SKIN_DEFAULT_NAME
        self.defaultSkinInfo = CJSkinSwift._dicFromSkinHistoryInfoWithKey(info: CJSkinSwift.skinPlistInfo(), key: self.defaultSkinName!)
        var skinName: String! = {
            var name = UserDefaults.standard.object(forKey: CJSkinCurrentSkinName)
            if name == nil {
                name = ""
            }
            return name as? String
        }()
        if skinName.count == 0 {
            skinName = self.defaultSkinName!
        }
        self.skinName = skinName
        self.skinInfo = CJSkinSwift._dicFromSkinHistoryInfoWithKey(info: CJSkinSwift.skinPlistInfo(), key: self.skinName!)
        
    }
    static private func _dicFromSkinHistoryInfoWithKey(info:NSDictionary, key:String)-> NSDictionary{
        let dic: NSDictionary? = info.object(forKey: key) as? NSDictionary
        if dic != nil && (dic?.allKeys.count)! > 0 {
            return dic!
        }
        return NSDictionary.init()
    }
    
    // MARK: Skin change
    /// 触发换肤
    static public func skinChange(_ skinName: String, _ completion: SkinActionCompletion?)-> Void {
        do {
            try CJSkinSwift._changeSkinWithName(skinName: skinName)
            if completion != nil {
                completion!(true,"换肤成功")
            }
        } catch let error {
            let msg = "皮肤包：\(skinName)，换肤出错：\(error.localizedDescription)"
            SkinLog(msg)
            if completion != nil {
                completion!(false,msg)
            }
        }
    }
    static private func _changeSkinWithName(skinName: String) throws -> Void {
        if skinName.isEmpty {
            throw CJSkinError.CJSkinNameIsNull
        }
        let skinInfo: NSDictionary? = _dicFromSkinHistoryInfoWithKey(info: CJSkinSwift.skinPlistInfo(), key: skinName)
        if skinInfo?.allKeys.count == 0 {
            throw CJSkinError.CJSkinNameNotExists
        }
        UserDefaults.standard.setValue(skinName, forKey: CJSkinCurrentSkinName)
        CJSkinSwift.manager.skinName = skinName
        CJSkinSwift.manager.skinInfo = skinInfo
        NotificationCenter.default.post(name: Notification.Name(CJSkinUpdateAndImageDownloadAgainNotification), object: nil)
        NotificationCenter.default.post(name: Notification.Name(CJSkinUpdateNotification), object: nil)
    }
    
    /// 更新皮肤包配置信息
    static public func updateSkinPlistInfo(_ skinPlistInfo: NSDictionary, _ completion: SkinActionCompletion?)-> Void {
        do {
            try CJSkinSwift._updateSkinPlistInfoData(skinPlistInfo: skinPlistInfo)
            if completion != nil {
                completion!(true,"更新皮肤包配置信息成功")
            }
        } catch let error {
            let msg = "更新skin_plist信息出错：\(error.localizedDescription)，\n skin_plist：\(skinPlistInfo)"
            SkinLog(msg)
            if completion != nil {
                completion!(false,msg)
            }
        }
    }
    static private func _updateSkinPlistInfoData(skinPlistInfo: NSDictionary!)throws -> Void {
        let dic: NSMutableDictionary = NSMutableDictionary.init()
        let oldSkinHistoryInfo: NSDictionary? = NSDictionary.init(contentsOfFile: CJSkinSandboxPlistPath) ?? NSDictionary.init()
        dic.addEntries(from: oldSkinHistoryInfo as! [AnyHashable : Any])
        dic.addEntries(from: skinPlistInfo as! [AnyHashable : Any])
        
        if !dic.write(toFile: CJSkinSandboxPlistPath, atomically: true) {
            throw CJSkinError.CJSkinInfoUpdateFail
        }
    }
    
    /// 删除指定皮肤包，如果删除的刚好是当前皮肤包，则将APP皮肤更换为默认（default）皮肤
    static public func removeSkin(_ skinName: String, _ completion: SkinActionCompletion?)-> Void {
        do {
            try CJSkinSwift._removeSkinPackWithName(skinName: skinName)
            if completion != nil {
                completion!(true,"删除成功")
            }
        } catch let error {
            let msg = "皮肤包：\(skinName)，删除皮肤出错：\(error.localizedDescription)"
            SkinLog(msg)
            if completion != nil {
                completion!(false,msg)
            }
        }
    }
    static private func _removeSkinPackWithName(skinName: String)throws -> Void {
        if skinName.isEmpty {
            throw CJSkinError.CJSkinNameIsNull
        }
        let info: NSMutableDictionary? = NSMutableDictionary.init(contentsOfFile: CJSkinSandboxPlistPath) ?? NSMutableDictionary.init()
        if ((info?.object(forKey: skinName)) == nil) {
            throw CJSkinError.CJSkinNameNotExists
        }
        if skinName == CJ_SKIN_DEFAULT_NAME {
            throw CJSkinError.CJSkinRemoveDefaultError
        }
        info?.removeObject(forKey: skinName)
        if info!.write(toFile: CJSkinSandboxPlistPath, atomically: true) {
            //删除成功，如果删除的刚好是当前皮肤包，则将APP皮肤更换为默认模式
            if skinName == CJSkinSwift.manager.skinName {
                do {
                    try CJSkinSwift._changeSkinWithName(skinName: CJ_SKIN_DEFAULT_NAME)
                }catch let error {
                    SkinLog("删除当前皮肤包：\(skinName) 后，切换为默认皮肤包（default）出错：\(error.localizedDescription)")
                }
            }
            //删除以皮肤压缩包zip方式整体下载的对应皮肤图片：Library/Caches/CJSkin/skinName 目录下的图片
            self.clearImageCachePath(SkinCachePath(skinName), nil)
            //删除指定url方式下载的在线图片： Library/Caches/CJSkin/CJSkinImage/skinName 目录下的图片
            self.clearImageCachePath(SkinCachePath("\(CJSkinImageCahcePathName)/\(skinName)"), nil)
        }else{
            throw CJSkinError.CJSkinInfoUpdateFail
        }
    }
    
    static private func _clearCache(_ path: String, _ completion: SkinActionCompletion?) -> Void {
        DispatchQueue.global(qos: .unspecified).async {
            do {
                try FileManager.default.removeItem(at: URL.init(fileURLWithPath: path))
                if nil != completion {
                    DispatchQueue.main.async {
                        completion!(true,"清除缓存成功")
                    }
                }
            } catch let error {
                SkinLog("清除缓存出错：\(path) \n error：\(error.localizedDescription)")
                if nil != completion {
                    DispatchQueue.main.async {
                        completion!(false,"清除缓存出错：\(error.localizedDescription)")
                    }
                }
            }
        }
    }
    /// 清除指定图片缓存
    /// - Parameter path: 缓存路径
    /// - Returns: Bool
    static internal func clearImageCachePath(_ path: String, _ completion: SkinActionCompletion?) -> Void {
        DispatchQueue.global(qos: .unspecified).async {
            if true == FileManager.default.fileExists(atPath: path) {
                let parentPath = URL.init(fileURLWithPath: path).deletingLastPathComponent()
                do {
                    var files : [String]
                    try files = FileManager.default.contentsOfDirectory(atPath: parentPath.path)
                    if files.count == 1 {
                        self._clearCache(parentPath.path, completion)
                    }else{
                        self._clearCache(path, completion)
                    }
                } catch {
                    self._clearCache(path, completion)
                }
            }else{
                SkinLog("缓存不存在：\(path)")
                if nil != completion {
                    DispatchQueue.main.async {
                        completion!(false,"缓存不存在：\(path)")
                    }
                }
            }
        }
    }
    /// 清除所有在线皮肤图片缓存
    static public func clearAllSkinImageCache(_ completion: SkinActionCompletion?) -> Void {
        let path = SkinCachePath(CJSkinImageCahcePathName)
        if true == FileManager.default.fileExists(atPath: path) {
            self._clearCache(path, completion)
        }else{
            if completion != nil {
                completion!(true,"在线皮肤图片缓存为空")
            }
        }
    }
    
    /// 下载皮肤包压缩资源并自动解压更新
    /// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    /// - Example.zip
    ///   - CJSkin.plist
    ///   - newSkin
    ///     - top.png
    ///     - bottom.png
    ///     - ...
    /// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    /// 皮肤包压缩资源示例说明：
    /// 1、压缩包内必须包含 CJSkin.plist 皮肤配置说明文件，“newSkin”文件夹表示新增皮肤包名称（新增皮肤包可以多个），其与CJSkin.plist处于同级文件目录下
    /// 2、CJSkin.plist 文件内填写"newSkin"皮肤的配置信息，如果有多个皮肤则全部都要对应填写
    /// 3、“newSkin”文件夹内放置该皮肤包的所有图片资源，如果图片有别名则在CJSkin.plist内配置说明；
    ///     例如：{"newSkin":{"Image":{"顶部图片":"top"}}}，对应的实际图片可以是top@2x.png、top@3x.png，或者top.jpeg
    /// 4、将"newSkin"文件夹、CJSkin.plist文件放入新建文件夹（Example），并压缩为"Example.zip"便是最终的皮肤包压缩资源
    ///
    /// - Parameters:
    ///   - url: 压缩包资源下载地址
    ///   - completion: 结果回调
    /// - Returns: Void
    static public func downloadSkinZip(url: String, completion:@escaping SkinActionCompletion) -> Void {
        CJSkinTool.download(url, filePath: nil) { (result, response) in
            switch (result) {
                case .success(let str):
                    self.unzip(str) { result in
                        switch (result) {
                            case .success(let str):
                                completion(true, str)
                            break
                            case .failure(let error):
                                completion(false, error.localizedDescription)
                            break
                        }
                    }
                break
                case .failure(let error):
                    completion(false, error.localizedDescription)
                break
            }
        }
    }
    
    /// 是否从main bundle内重新读取皮肤配置，若开启，可调试修改 CJSkin.plist 配置中的内容，否则从 app 沙盒内的读取配置
    /// 如果开启，必须在任意控件设置换肤属性前调用
    /// 此开关只在Debug模式下有效（注意⚠️：如果组件是以lib引入，lib要判断下是不是Debug模式下包）
    static public func debugLoadSkinFromMainBundle()-> Void {
#if (DEBUG)
        var appVersion: String {
            if let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String {
                return version
            }
            return "1.0.0"
        }
        let oldSkinHistoryInfo: NSDictionary? = NSDictionary.init(contentsOfFile: CJSkinSandboxPlistPath) ?? NSDictionary.init()
        if (oldSkinHistoryInfo?.allKeys.count)! > 0 {
            CJSkinSwift.manager._updateSkinSandboxPlistInfo(appVersion: appVersion, oldSkinHistoryInfo: oldSkinHistoryInfo)
            CJSkinSwift.manager._readSkinInfo()
        }
#else
        SkinLog("release 模式")
#endif
    }
    
    /// 是否开启CJSkinLog
    static public func skinLogEnable(_ logEnable: Bool)-> Void {
        CJSKinlogEnable = logEnable
    }
}

// MARK: - SkinZipUpdate
fileprivate extension CJSkinSwift {
    static func unzip(_ zipPath: String, _ completion:@escaping ((Result<String, Error>) -> Void)) -> Void {
        DispatchQueue.global(qos: .unspecified).async {
            let unzipDic = UUID.init().uuidString
            let unzipPath = SkinCachePath("CJSkinUnZip_\(unzipDic)",true)
            guard FileManager.default.fileExists(atPath: unzipPath) else {
                SkinLog("皮肤压缩包下载后解压路径创建失败：\(zipPath)")
                DispatchQueue.main.async {
                    completion(.failure(CJSkinError.CJSkinCreateDirectoryError))
                }
                return
            }
            
            let success: Bool = SSZipArchive.unzipFile(atPath: zipPath,
                                                       toDestination: unzipPath,
                                                       preserveAttributes: true,
                                                       overwrite: true,
                                                       nestedZipLevel: 1,
                                                       password: nil,
                                                       error: nil,
                                                       delegate: nil,
                                                       progressHandler: nil,
                                                       completionHandler: nil)
            
            CJSkinSwift.clearImageCachePath(zipPath, nil)
            if success == false {
                SkinLog("皮肤压缩包解压失败：\(zipPath)")
                DispatchQueue.main.async {
                    completion(.failure(CJSkinError.CJSkinUnzipError))
                }
                return
            }
            
            do {
                var files : [String]
                try files = FileManager.default.contentsOfDirectory(atPath: unzipPath)
                for (_, item) in files.enumerated() {
                    if self.pathIsDirectory(parentPath: unzipPath, file: item) {
                        self.updateSkin("\(unzipPath)/\(item)") { result in
                            switch (result) {
                                case .success(let str):
                                    DispatchQueue.main.async {
                                        completion(.success(str))
                                    }
                                break
                                case .failure(let error):
                                    DispatchQueue.main.async {
                                        completion(.failure(error))
                                    }
                                break
                            }
                        }
                    }else{
                        self.updateSkin(unzipPath) { result in
                            switch (result) {
                                case .success(let str):
                                    DispatchQueue.main.async {
                                        completion(.success(str))
                                    }
                                break
                                case .failure(let error):
                                    DispatchQueue.main.async {
                                        completion(.failure(error))
                                    }
                                break
                            }
                        }
                    }
                }
                //更新结束，删除解压压缩包的临时文件夹
                CJSkinSwift.clearImageCachePath(unzipPath, nil)
            } catch let error {
                SkinLog("获取皮肤压缩包资源失败：\(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
    }
    
    static func updateSkin(_ skinResourcePath: String, _ completion:@escaping ((Result<String, Error>) -> Void)) -> Void {
        do {
            let fileManager = FileManager.default
            let zipName = URL.init(fileURLWithPath: skinResourcePath).lastPathComponent
            //压缩包文件夹下的所有文件名（包含文件夹）
            var tempArray : [String]
            try tempArray = fileManager.contentsOfDirectory(atPath: skinResourcePath)
            if tempArray.count == 0 {
                SkinLog("皮肤压缩包资源为空，压缩包名称：\(zipName)")
                completion(.failure(CJSkinError.CJSkinZipIsNullError))
                return
            }
            
            var skinPlistInfo: NSDictionary?
            for (_, item) in tempArray.enumerated() {
                if item.containsIgnoringCase(find: "CJSkin.plist") {
                    skinPlistInfo = NSDictionary.init(contentsOfFile: "\(skinResourcePath)/\(item)")
                    break
                }
            }
            
            if nil == skinPlistInfo {
                SkinLog("皮肤资源更新失败！！压缩包名称：\(zipName)，其中不存在配置描述文件 CJSkin.plist！！")
                completion(.failure(CJSkinError.CJSkinZipWithoutSkinPlistError))
                return
            }
            
            //换肤资源目标路径
            let toCJSkinPath = SkinCachePath("");
            //已有的皮肤包资源文件夹
            var oldSkinArray = try? fileManager.contentsOfDirectory(atPath: toCJSkinPath)
            if oldSkinArray == nil {
                oldSkinArray = Array.init()
            }
            
            var resultErrorMsg: String = ""
            //将压缩包下载后的资源，移动到 Library/Caches/CJSkin/ 路径下
            //首先遍历获取压缩包内 CJSkin.plist 中记录的所有皮肤包
            for (key,_) in skinPlistInfo! {
                let skinName: String = key as? String ?? ""
                //只处理压缩包内 CJSkin.plist 中有记录的皮肤包文件夹，其他的忽略
                if tempArray.contains(skinName) {
                    //获取到当前皮肤资源文件夹路径
                    let atSkinFilePath = skinResourcePath + "/" + skinName
                    //是有效的皮肤包文件夹
                    if self.pathIsDirectory(parentPath: "", file: atSkinFilePath) {
                        //如果已存在同名的皮肤包资源文件夹，执行覆盖资源
                        if oldSkinArray!.contains(skinName) {
                            resultErrorMsg = self.coverSkin(atPath: atSkinFilePath, toPath: "\(toCJSkinPath)/\(skinName)", fileManager: fileManager)
                        }
                        //否则直接添加到换肤资源下
                        else{
                            resultErrorMsg = self.moveItem(atPath: atSkinFilePath, toPath: "\(toCJSkinPath)/\(skinName)", fileManager: fileManager)
                        }
                    }
                }
            }
            
            if false == resultErrorMsg.isEmpty {
                completion(.failure(CJSkinError.CJSkinZipUpdateError))
                return
            }
            
            //资源移动完成，将新的CJSkin.plist 内容更新到沙盒文件内
            CJSkinSwift.updateSkinPlistInfo(skinPlistInfo!) { (result, msg) in
                if false == result {
                    completion(.failure(CJSkinError.CJSkinInfoUpdateFail))
                }else{
                    completion(.success("更新成功"))
                }
            }
        } catch let error {
            SkinLog("获取皮肤压缩包资源失败：\(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    static func coverSkin(atPath: String, toPath: String, fileManager: FileManager)-> String {
        do {
            //需要替换的皮肤包资源内容
            var currentSkinFileArray : [String]
            try currentSkinFileArray = fileManager.contentsOfDirectory(atPath: atPath)
            
            //旧的皮肤包资源内容
            var oldSkinFileArray : [String]
            try oldSkinFileArray = fileManager.contentsOfDirectory(atPath: atPath)
            
            var resultErrorMsg: String = ""
            for (_, fileName) in currentSkinFileArray.enumerated() {
                //旧的皮肤包内存在同名文件，先删除旧的同名文件
                if oldSkinFileArray.contains(fileName) {
                    resultErrorMsg = self.removeItem(atPath: "\(toPath)/\(fileName)", fileManager: fileManager)
                }
                resultErrorMsg = self.moveItem(atPath: "\(atPath)/\(fileName)", toPath: "\(toPath)/\(fileName)", fileManager: fileManager)
            }
            return resultErrorMsg
        } catch let error {
            SkinLog("获取皮肤压缩包资源失败：\(error.localizedDescription)")
            return "获取皮肤压缩包资源失败：\(error.localizedDescription)"
        }
    }
    
    static func moveItem(atPath: String, toPath: String, fileManager: FileManager) -> String {
        do {
            try fileManager.moveItem(atPath: atPath, toPath: toPath)
            return ""
        } catch let error {
            SkinLog("更新替换皮肤压缩包资源失败：\(error.localizedDescription)")
            return "更新替换皮肤压缩包资源失败：\(error.localizedDescription)"
        }
    }
    
    static func removeItem(atPath: String, fileManager: FileManager) -> String {
        do {
            try fileManager.removeItem(atPath: atPath)
            return ""
        } catch let error {
            SkinLog("更新移除旧的压缩包资源失败：\(error.localizedDescription)")
            return "更新移除旧的压缩包资源失败：\(error.localizedDescription)"
        }
    }
    
    static func pathIsDirectory(parentPath: String, file: String) -> Bool {
        var fullPath = file
        if false == parentPath.isEmpty {
            fullPath = parentPath + "/" + file
        }
        var isDir : ObjCBool = false
        if FileManager.default.fileExists(atPath: fullPath, isDirectory:&isDir) {
            return isDir.boolValue
        }
        return false
    }
}
