//
//  CJSkinTool.swift
//  CJSkinSwift
//
//  Created by lele8446 on 2021/8/16.
//

import UIKit
import CommonCrypto
import Alamofire

public enum CJSkinValueType: Int {
    /// 未知皮肤资源
    case skinTypeUnknown                = -1
    
    /// 颜色皮肤资源（支持格式包括：#FFC0C0C0  #C0C0C0  0xC0C0C0）
    case skinTypeColor                  = 0
    
    /// 图片皮肤资源
    case skinTypeImage                  = 1
    
    /// 字体皮肤资源
    case skinTypeFont                   = 2
    
    /// 颜色生成纯色图片皮肤资源
    case skinTypeImageFromColor         = 3
}

internal let CJSkinUpdateAndImageDownloadAgainNotification: String = "CJ.skin.skinUpdateAndImageDownloadAgain.notification"

internal func SkinCachePath(_ skinName: String, _ needCreate: Bool = false) -> String {
    let paths:Array<String> = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
    var path = paths[0]
    var skinCachePathName: String {
        if skinName.count > 0 {
            return "CJSkin/" + skinName
        }
        return "CJSkin"
    }
    path = path + "/" + skinCachePathName
    if true == needCreate {
        if false == FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                SkinLog("沙盒缓存路径创建失败：\(path)")
            }
        }
    }
//    SkinLog("SkinCachePath：\(path)")
    return path
}

/** 换肤配置文件 CJSkin.plist 中固定的key 值 */
private let CJSkinColorTypeKey: String                = "Color"
private let CJSkinImageTypeKey: String                = "Image"
private let CJSkinFontTypeKey: String                 = "Font"
private let CJSkinFontNameKey: String                 = "Name"
private let CJSkinFontSizeKey: String                 = "Size"

/// 沙盒中记录所有皮肤配置信息的plist文件名
internal let CJSkinInfoHistoryName: String  = "CJSkinInfoHistory"
/// 沙盒中记录所有在线图片缓存的文件夹名称
internal let CJSkinImageCahcePathName: String  = "CJSkinImage"

/// 获取图片资源响应结果实体
public struct SkinImageRespone {
    /// 是否成功获取图片资源
    public var result: Bool
    /// 获取说明信息
    public var message: String
    /// 所在皮肤包名
    public var skinName: String
    /// 图片资源
    public var image: UIImage?
    /// 图片来源
    public var imageSource: SkinImageSource
    
    /// 图片资源读取来源说明
    public enum SkinImageSource {
        /// 内存缓存
        case memoryCache
        /// 磁盘缓存
        case diskCache
        /// 网络下载
        case network
    }

    public init(result: Bool, message: String, skinName: String, image: UIImage? = nil , imageSource: SkinImageSource) {
        self.result = result
        self.message = message
        self.skinName = skinName
        self.image = image
        self.imageSource = imageSource
    }
}

/// 快速获取当前皮肤包资源转换工具类
@discardableResult
public func SkinTool(_ key:String, _ type: CJSkinValueType)-> CJSkinTool {
    return CJSkinTool.tool(key: key, type: type)
}
/// 换肤资源转换工具类，通过该类的实例映射获取不同皮肤包内对应的颜色、图片、字体
public class CJSkinTool: NSObject {
    /// 皮肤资源key
    public private(set) var key: String!
    /// 皮肤资源类型
    public private(set) var valueType: CJSkinValueType!
    /// 皮肤资源为颜色，颜色透明度（默认1）
    public var alpha: CGFloat = 1
    /// 皮肤资源为字体，字体类型(正常、加粗、斜体)，默认正常。只在字体样式为系统字体的情况下有效
    public var fontType: CJSkinFontType = .skinFontRegular
    
    /// 皮肤资源为由颜色生成的图片，图片大小 (默认 {1.0f,1.0f} )
    fileprivate var colorImageSize: CGSize = CGSize.init(width: 1.0, height: 1.0)
    /// 皮肤资源为图片，图片渲染模式
    public var imageRenderingMode: UIImage.RenderingMode = UIImage.RenderingMode(rawValue: -1)!
    
    public weak var afterDownloadRefreshSkinTarget: NSObject?
    
    @available(iOS,unavailable,message: "请使用init(key:type:)初始化")
    public override init() {
        super.init()
        self.key = ""
        self.valueType = .skinTypeUnknown
    }
    
    /// 指定初始化函数
    /// - Parameters:
    ///   - key: 皮肤资源key
    ///   - type: 资源类型
    init(key: String, type: CJSkinValueType) {
        super.init()
        self.key = key
        self.valueType = type
    }
    
    /// 换肤资源转换工具类
    /// - Parameters:
    ///   - key: 皮肤资源key
    ///   - type: 资源类型
    /// - Returns: CJSkinTool
    public static func tool(key: String, type: CJSkinValueType)-> CJSkinTool {
        return CJSkinTool.init(key: key, type: type)
    }
    
    deinit {
//        debugPrint("====: deinit；\(self)")
    }
    
    ///  同步获取皮肤资源。
    ///  1、从当前皮肤包同步获取对应的皮肤资源（UIColor、UIImage或者UIFont），
    ///  2、如果不存在则取defaultValue（defaultValue对应默认皮肤包“default”中的同名资源），如果defaultValue 也为nil，则取：UIColor.white、UIFont.systemFont(ofSize:14)、UIImage.init()
    ///  3、注意⚠️：当皮肤资源为在线网络图片并且本地无缓存时，调用skinValue()将返回UIImage.init()！此时请使用asyncGetSkinImage方法异步获取图片
    /// - Returns: 皮肤值UIColor、UIImage或者UIFont
    @discardableResult
    public func skinValue()-> NSObject {
        var value: NSObject = NSObject.init()
        if self.valueType == .skinTypeUnknown {
            SkinLog("未知皮肤元素，key：\(self.key!)")
            assert(((0) != 0), "未知皮肤元素，请检查！！key：\(self.key!)")
        }
        else if self.valueType == .skinTypeColor {
            value = skinColorForKey(self.key!,CJSkinSwift.skinInfo(),CJSkinSwift.skinName())
            assert((value.isKind(of: UIColor.self)), "CJSkin 获取UIColor资源出错，key:\(self.key!)")
        }
        else if self.valueType == .skinTypeFont {
            value = skinFontForKey(self.key!,CJSkinSwift.skinInfo(),CJSkinSwift.skinName())
            assert((value.isKind(of: UIFont.self)), "CJSkin 获取UIFont资源出错，key:\(self.key!)")
        }
        else if self.valueType == .skinTypeImage {
            value = skinImageForKey(self.key!,CJSkinSwift.skinInfo(),CJSkinSwift.skinName())
            assert((value.isKind(of: UIImage.self)), "CJSkin 获取UIImage资源出错，key:\(self.key!)")
        }
        else if self.valueType == .skinTypeImageFromColor {
            value = skinImageFromColorForKey(self.key!,CJSkinSwift.skinInfo(),CJSkinSwift.skinName())
            assert((value.isKind(of: UIImage.self)), "CJSkin 获取UIImage资源出错，key:\(self.key!)")
        }
        return value
    }
    
    /// 异步获取当前皮肤包的指定图片
    /// - Parameters:
    ///   - completion: 结果回调
    /// - Returns: void
    public func asyncGetSkinImage(_ completion: @escaping (SkinImageRespone)->Void)->Void {
        if self.valueType == .skinTypeImage {
            let skinName = CJSkinSwift.skinName()
            self._getSkinImageForKey(key: self.key, skinInfo: CJSkinSwift.skinInfo(), skinName: skinName, readDefaultValue: false, needDownload: true) { respone in
                var result = respone
                var resultImage = respone.image
                if resultImage != nil && self.imageRenderingMode.rawValue >= 0 {
                    resultImage = respone.image?.withRenderingMode(self.imageRenderingMode)
                    result.image = resultImage
                }
                completion(result)
            }
        }
    }
    
    /// 判断当前皮肤包是否存在指定皮肤资源
    /// - Parameters:
    ///   - key: 皮肤资源key
    ///   - type: 皮肤资源类型
    /// - Returns: Bool
    fileprivate static func skinExistsWithKey(key: String, type: CJSkinValueType)->Bool {
        var result: Bool = false
        switch type {
        
        case .skinTypeColor:
            let rgbValue: String = _skinPackValue(CJSkinSwift.skinInfo(), key: key, type: type, skinName: CJSkinSwift.skinName())
            result = !rgbValue.isEmpty
            break
        case .skinTypeImageFromColor:
            let rgbValue: String = _skinPackValue(CJSkinSwift.skinInfo(), key: key, type: type, skinName: CJSkinSwift.skinName())
            result = !rgbValue.isEmpty
            break
            
        case .skinTypeFont:
            let fontInfo: NSDictionary? = _skinPackFontValue(CJSkinSwift.skinInfo(), key: key, skinName: CJSkinSwift.skinName())
            result = (fontInfo != nil)
            break
            
        case .skinTypeImage:
            let skinTool: CJSkinTool = CJSkinTool.init(key: key, type: .skinTypeImage)
            let image: UIImage? = skinTool._getSkinImageForKey(key: key, skinInfo: CJSkinSwift.skinInfo(), skinName: CJSkinSwift.skinName(), readDefaultValue: false, needDownload: false, completionHandler: {r in})
            result = (image != nil)
            break
        default:
            result = false
            break
        }
        
        return result
    }
    
    // MARK: - 根据key获取皮肤包信息
    /// 根据key获取Color、Image皮肤信息，结果为String
    /// - Parameters:
    ///   - info: 当前皮肤信息
    ///   - key: 皮肤值对应的key
    ///   - type: 皮肤值类型
    /// - Returns: 皮肤值
    fileprivate static func _skinPackValue(_ info: NSDictionary, key: String, type: CJSkinValueType, skinName: String)->String {
        let valueTypeKey = (type == .skinTypeColor || type == .skinTypeImageFromColor) ? CJSkinColorTypeKey : CJSkinImageTypeKey
        let valueInfo = info.value(forKey: valueTypeKey)
//        let errorMsg = (type == .skinTypeColor || type == .skinTypeImageFromColor) ? "颜色" : "图片"
        guard ((valueInfo as? NSDictionary) != nil) else {
//            SkinLog("皮肤包：\(skinName)，\(errorMsg)不存在，key= \(key)")
            return ""
        }
        var value: String? = (valueInfo as? NSDictionary)!.value(forKey: key) as? String
        if value == nil {
//            SkinLog("皮肤包：\(skinName)，\(errorMsg)不存在，key= \(key)")
            value = ""
        }
        return value!
    }
    /// 根据key获取Font皮肤信息，结果为NSDictionary
    fileprivate static func _skinPackFontValue(_ info: NSDictionary, key: String, skinName: String)->NSDictionary? {
        let valueInfo = info.value(forKey: CJSkinFontTypeKey)
        guard ((valueInfo as? NSDictionary) != nil) else {
//            SkinLog("皮肤包：\(skinName)，字体不存在，key= \(key)")
            return nil
        }
        let value: NSDictionary? = (valueInfo as? NSDictionary)!.value(forKey: key) as? NSDictionary
        if value == nil {
//            SkinLog("皮肤包：\(skinName)，字体不存在，key= \(key)")
        }
        return value
    }
    
    
}
// MARK: - Color
/// 当前皮肤包是否存在指定颜色
@discardableResult
public func SkinColorExists(_ key:String)->Bool {
    return CJSkinTool.skinExistsWithKey(key: key, type: .skinTypeColor)
}
/// 从当前皮肤包，快速获取颜色，可指定颜色透明度
@discardableResult
public func SkinColor(_ key:String, _ alpha:CGFloat = 1)->UIColor {
    return _SkinColorAlpha(key, alpha)
}
/// 从当前皮肤包，快速获取，并指定颜色透明度
private func _SkinColorAlpha(_ key:String, _ alpha:CGFloat)->UIColor {
    let skinTool:CJSkinTool = CJSkinTool.init(key: key, type: .skinTypeColor)
    skinTool.alpha = alpha
    return skinTool.skinValue() as! UIColor
}
fileprivate extension CJSkinTool {
    /// 根据十六进制获取颜色
    private func _skinColorRGBHex(_ rgbValue: String) -> UIColor? {
        if rgbValue.isEmpty {
//            SkinLog("16进制字符串转UIColor失败，字符串rgbValue为空")
            return nil
        }
        ///  支持格式包括： #ff21af64   #21af64   0x21af64
        else if (rgbValue.hasPrefix("#") || (rgbValue.hasPrefix("0x"))) {
            let mutStr = (rgbValue as NSString).mutableCopy() as! NSMutableString
            
            if (rgbValue.hasPrefix("#")) {
                mutStr.deleteCharacters(in: NSRange.init(location: 0, length: 1))
            } else {
                mutStr.deleteCharacters(in: NSRange.init(location: 0, length: 2))
            }
            
            if (mutStr.length == 6) {
                mutStr.insert("ff", at: 0)
            }
            
            let aStr = mutStr.substring(with: NSRange.init(location: 0, length: 2))
            let rStr = mutStr.substring(with: NSRange.init(location: 2, length: 2))
            let gStr = mutStr.substring(with: NSRange.init(location: 4, length: 2))
            let bStr = mutStr.substring(with: NSRange.init(location: 6, length: 2))
            
            let alpha = aStr.hexValue()
            let red = rStr.hexValue()
            let green = gStr.hexValue()
            let blue = bStr.hexValue()
            
            return UIColor.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: CGFloat(alpha) / 255.0)
        }
        else{
//            SkinLog("16进制字符串转UIColor格式不支持，字符串rgbValue：\(rgbValue)")
            return nil
        }
    }
    
    private func skinColorForKey(_ key: String,_ skinInfo: NSDictionary,_ skinName: String)-> UIColor {
        let rgbValue: String = CJSkinTool._skinPackValue(skinInfo, key: key, type: .skinTypeColor, skinName: skinName)
        var color = _skinColorRGBHex(rgbValue)
        if color == nil {
            //降级读取默认皮肤包资源
            if skinName != CJ_SKIN_DEFAULT_NAME {
                color = skinColorForKey(key, CJSkinSwift.defaultSkinInfo(),CJ_SKIN_DEFAULT_NAME)
            }
            if color == nil {
                SkinLog("皮肤包：\(skinName)，获取颜色失败，defaultValue取UIColor.white，key= \(key)")
                color = UIColor.white
            }else{
                SkinLog("皮肤包：\(skinName)，获取颜色失败，降级读取 defaultValue 成功，key= \(key)")
            }
        }
        if self.alpha < 1 {
            color = color?.withAlphaComponent(self.alpha)
        }
        return color!
    }
}

// MARK: - Font
/// 皮肤资源为字体，字体类型
public enum CJSkinFontType: Int {
    /// 正常
    case skinFontRegular                 = 0

    /// 加粗
    case skinFontBold                    = 1
    
    /// 斜体
    case skinFontItalic                  = 2
}
/// 当前皮肤包是否存在指定字体
@discardableResult
public func SkinFontExists(_ key:String)->Bool {
    return CJSkinTool.skinExistsWithKey(key: key, type: .skinTypeFont)
}
/// 从当前皮肤包，快速获取字体，可指定字体类型（只在字体样式为系统字体的情况下有效）
@discardableResult
public func SkinFont(_ key:String, _ fontType:CJSkinFontType = .skinFontRegular)->UIFont {
    return _SkinFontType(key, fontType)
}
/// 从当前皮肤包，快速获取字体，并指定字体类型（只在字体样式为系统字体的情况下有效）
@discardableResult
private func _SkinFontType(_ key:String, _ fontType:CJSkinFontType)->UIFont {
    let skinTool:CJSkinTool = CJSkinTool.init(key: key, type: .skinTypeFont)
    skinTool.fontType = fontType
    return skinTool.skinValue() as! UIFont
}
fileprivate extension CJSkinTool {
    private func skinFontForKey(_ key: String,_ skinInfo: NSDictionary,_ skinName: String)-> UIFont {
        var fontInfo: NSDictionary? = CJSkinTool._skinPackFontValue(skinInfo, key: key, skinName: skinName)
        if fontInfo == nil {
            //降级读取默认皮肤包资源
            if skinName != CJ_SKIN_DEFAULT_NAME {
                fontInfo = CJSkinTool._skinPackFontValue(CJSkinSwift.defaultSkinInfo(), key: key, skinName: CJ_SKIN_DEFAULT_NAME)
                if fontInfo == nil {
                    SkinLog("皮肤包：\(skinName)，获取字体失败，defaultValue取 UIFont.systemFont(ofSize:14)，key= \(key)")
                }else{
                    SkinLog("皮肤包：\(skinName)，获取字体失败，降级读取 defaultValue 成功，key= \(key)")
                }
            }
        }
        var font: UIFont?
        var fontName: String?
        var fontSize: CGFloat?
        if fontInfo != nil {
            fontName = fontInfo?.value(forKey: CJSkinFontNameKey) as? String
            let size = fontInfo?.value(forKey: CJSkinFontSizeKey)
            if ((size as? NSString) == nil) {
                fontSize = 14
            }
            fontSize = CGFloat((size as! NSString).floatValue)
        }
        if fontSize == nil || fontSize == 0 {
            fontSize = 14
        }
        if fontName != nil {
            font = UIFont.init(name: fontName!, size: fontSize!)
        }
        if font == nil {
            if self.fontType == .skinFontBold {
                font = UIFont.boldSystemFont(ofSize: fontSize!)
            }
            else if self.fontType == .skinFontItalic {
                font = UIFont.italicSystemFont(ofSize: fontSize!)
            }else{
                font = UIFont.systemFont(ofSize: fontSize!)
            }
        }
        return font!
    }
}

// MARK: - ImageFromColor
/// 从当前皮肤包，快速读取颜色生成图片，可指定图片大小（size默认大小{1.0f,1.0f}）
@discardableResult
public func SkinImageFromColor(_ key:String, _ size:CGSize = CGSize.init(width: 1.0, height: 1.0))->UIImage {
    return _SkinImageFromColorWithSize(key, size)
}
/// 从当前皮肤包，快速读取颜色生成图片皮肤资源，并指定图片大小
@discardableResult
private func _SkinImageFromColorWithSize(_ key:String, _ size:CGSize)->UIImage {
    let skinTool:CJSkinTool = CJSkinTool.init(key: key, type: .skinTypeImageFromColor)
    skinTool.colorImageSize = size
    return skinTool.skinValue() as! UIImage
}
fileprivate extension CJSkinTool {
    private func skinImageFromColorForKey(_ key: String,_ skinInfo: NSDictionary,_ skinName: String)-> UIImage {
        let color: UIColor = skinColorForKey(key, skinInfo, skinName)
        var image:UIImage? = self.getImageFromColor(color: color, size: self.colorImageSize)
        if image == nil {
            image = UIImage.init()
            SkinLog("皮肤包：\(skinName)，根据颜色生成图片失败，取UIImage.init()，key= \(key)")
        }
        if self.imageRenderingMode.rawValue >= 0 {
            image = image?.withRenderingMode(self.imageRenderingMode)
        }
        return image!
    }
    private func getImageFromColor(color: UIColor, size: CGSize)->UIImage? {
        autoreleasepool {
            let rect: CGRect = CGRect.init(x: 0, y: 0, width: size.width, height: size.height)
            UIGraphicsBeginImageContext(rect.size)
            let context: CGContext = UIGraphicsGetCurrentContext()!
            context.setFillColor(color.cgColor)
            context.fill(rect)
            let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image
        }
    }
}

// MARK: - Image
/// 当前皮肤包是否存在指定图片
@discardableResult
public func SkinImageExists(_ key:String)->Bool {
    return CJSkinTool.skinExistsWithKey(key: key, type: .skinTypeImage)
}
/// 从当前皮肤包，快速获取图片
/// 注意⚠️：
/// 1、当皮肤资源为在线网络图片并且本地无缓存时，调用skinValue()将返回UIImage.init()！可使用CJSkinTool 的 asyncGetSkinImage方法异步获取图片
/// 2、如果有指定refreshSkinTarget，当网络图片下载成功后，指定UI对象将会自动调用refreshSkin()进行重刷
///
/// 示例：
/// imageView.refreshSkin = { (weakSelf: NSObject) in
///    (weakSelf as! UIImageView).image = SkinImage("top", weakSelf)
/// }
///
/// - Parameters:
///   - key: 皮肤资源key
///   - afterDownloadRefreshSkinTarget: 指定刷新UI对象，当网络图片异步下载成功后，如果指定对象的refreshSkin不为空，那么将会自动调用target.refreshSkin()进行重刷
/// - Returns: UIImage
@discardableResult
public func SkinImage(_ key:String, _ afterDownloadRefreshSkinTarget:NSObject?)->UIImage {
    return SkinImageRenderingMode(key, UIImage.RenderingMode(rawValue: -1)!,afterDownloadRefreshSkinTarget)
}
/// 从当前皮肤包，快速获取图片，并指定图片渲染模式
/// 注意⚠️：
/// 1、当皮肤资源为在线网络图片并且本地无缓存时，调用skinValue()将返回UIImage.init()！可使用CJSkinTool 的 asyncGetSkinImage方法异步获取图片
/// 2、如果有指定afterDownloadRefreshSkinTarget，当网络图片下载成功后，指定UI对象将会自动调用refreshSkin()进行重刷
@discardableResult
public func SkinImageRenderingMode(_ key:String, _ imageRenderingMode:UIImage.RenderingMode, _ afterDownloadRefreshSkinTarget:NSObject?)->UIImage {
    let skinTool:CJSkinTool = CJSkinTool.init(key: key, type: .skinTypeImage)
    skinTool.imageRenderingMode = imageRenderingMode
    skinTool.afterDownloadRefreshSkinTarget = afterDownloadRefreshSkinTarget
    return skinTool.skinValue() as! UIImage
}
fileprivate extension CJSkinTool {
    private func skinImageForKey(_ key: String,_ skinInfo: NSDictionary,_ skinName: String)-> UIImage {
        var image: UIImage? = self._getSkinImageForKey(key: key, skinInfo: skinInfo, skinName: skinName, readDefaultValue: true, needDownload: true) { respone in
            if respone.result && skinName == CJSkinSwift.skinName() && respone.imageSource == .network {
                /// 网络图片下载成功，通知刷新图片
                if nil != self.afterDownloadRefreshSkinTarget  && nil != self.afterDownloadRefreshSkinTarget?.refreshSkin {
                    weak var weakSelf = self.afterDownloadRefreshSkinTarget
//                    SkinLog("皮肤包：\(skinName) 图片下载完成，当前皮肤= \(CJSkinSwift.skinName())，通知刷新，key= \(key)")
                    self.afterDownloadRefreshSkinTarget?.refreshSkin(weakSelf!)
                }
            }
        }
        
        if self.imageRenderingMode.rawValue >= 0 {
            image = image?.withRenderingMode(self.imageRenderingMode)
        }
        return image!
    }
    
    /// 获取图片，图片存储方式存在4种情况
    /// 1、默认皮肤包，Assets.xcassets内或直接放在项目工程下
    /// 2、其他皮肤包，项目初始化阶段以skin1.bundle的形式导入
    /// 3、在线下载的皮肤压缩包，解压后存储在：Library/Caches/CJSkin/皮肤包名/xxx.png路径下
    /// 4、CJSkin.plist中记录的皮肤信息包中，该图片是需要在线下载的图片
    /// - Parameters:
    ///   - key: 图片key
    ///   - skinInfo: 皮肤包信息
    ///   - skinName: 皮肤包名
    ///   - skinImageForKey: 是否skinImageForKey调用
    ///   - completionHandler: 下载回调
    /// - Returns: 返回图片
    @discardableResult
    private func _getSkinImageForKey(key: String,
                                     skinInfo: NSDictionary,
                                     skinName: String,
                                     readDefaultValue: Bool,
                                     needDownload: Bool,
                                     completionHandler: @escaping (SkinImageRespone)->Void)-> UIImage? {
        
        var image: UIImage?
        //从内存缓存NSCache读取
        image = CJSkinSwift.imageCache()?.object(forKey: self._imageCacheKey(key, skinName))
        if (image != nil) {
            completionHandler(SkinImageRespone.init(result: true, message: "获取图片成功", skinName: skinName, image: image, imageSource: .memoryCache))
            return image
        }
        
        //判断CJSkin.plist记录的皮肤信息包中是否存在该图片信息，如果没有，图片名取key
        var imageName: String = CJSkinTool._skinPackValue(skinInfo, key: key, type: .skinTypeImage, skinName: skinName)
        if imageName.isEmpty {
            imageName = key
        }
        
        /// 图片无需下载，图片引入包含3种方式：
        /// 1、默认皮肤包，Assets.xcassets内或直接放在项目工程下
        /// 2、其他皮肤包，项目初始化阶段以skin1.bundle的形式导入
        /// 3、在线下载的皮肤压缩包，解压后存储在：Library/Caches/CJSkin/皮肤包名/xxx.png路径下
        if false == imageName.isUrl {
            //默认皮肤包，首先从Assets.xcassets或项目工程中读取图片
            if skinName == CJ_SKIN_DEFAULT_NAME {
                image = UIImage.init(named: imageName)
                if (image != nil) {
                    completionHandler(SkinImageRespone.init(result: true, message: "获取图片成功", skinName: skinName, image: image, imageSource: .memoryCache))
                    return image
                }
            }
            
            //再从 Bundle 文件夹读取图片
            let skinBundlePath = Bundle.main.path(forResource: skinName, ofType: "bundle")
            let skinBundle = Bundle.init(path: (skinBundlePath ?? ""))
            if nil != skinBundle {
                let imageNameStr = "\(skinName).bundle/\(imageName)"
                image = UIImage.init(named: imageNameStr)
                if (image != nil) {
                    completionHandler(SkinImageRespone.init(result: true, message: "获取图片成功", skinName: skinName, image: image, imageSource: .memoryCache))
                    return image
                }
            }
            
            //在线下载的皮肤压缩包，从沙盒路径读取：Library/Caches/CJSkin/皮肤包名/xxx.png
            if imageName.count > 0 && (String(imageName.prefix(1)) == "/") {
                imageName = String(imageName.dropFirst(1))
            }
            let localFilePath = SkinCachePath("\(skinName)",false)
            image = self._getImageFromLocalPath(imagePath: localFilePath, skinName: skinName, key: key, imageName: imageName)
            if (image != nil) {
                completionHandler(SkinImageRespone.init(result: true, message: "获取图片成功", skinName: skinName, image: image, imageSource: .diskCache))
                return image
            }
            
            //图片资源不存在
            completionHandler(SkinImageRespone.init(result: false, message: "皮肤图片不存在", skinName: skinName, image: image, imageSource: .diskCache))
        }
        ///CJSkin.plist记录的皮肤信息包中，该图片是需要在线下载的图片
        else {
            //判断缓存是否存在
            //查找指定url是否存在沙盒缓存，默认一个url对应的缓存路径下只会有一份文件，如果存在多个则认为缓存无效并删除
            let localFilePath = CJSkinTool.searchUrlCachePath(url: imageName, filePath: "\(CJSkinImageCahcePathName)/\(skinName)")
            if false == localFilePath.isEmpty {
                //此处的localFilePath应该是包含具体文件名（含后缀）的缓存路径，因此获取图片imageName=""
                image = self._getImageFromLocalPath(imagePath: localFilePath, skinName: skinName, key: key, imageName: "")
                if (image != nil) {
                    completionHandler(SkinImageRespone.init(result: true, message: "获取图片成功", skinName: skinName, image: image, imageSource: .diskCache))
                    return image
                }
            }
            //未下载成功的网络图片，开始下载逻辑判断
            else{
                if needDownload {
    //                SkinLog("皮肤包：\(skinName)，获取在线图片还未下载，开始下载，key= \(key)，url= \(imageName)")
                    DispatchQueue.global(qos: .unspecified).async {
                        CJSkinTool.download(imageName, filePath: "\(CJSkinImageCahcePathName)/\(skinName)") { (result, respone) in
                            switch (result) {
                                case .success(let imagePath):
                                    let resultImage = self._getImageFromLocalPath(imagePath: imagePath, skinName: skinName, key: key, imageName: "")
                                    if resultImage != nil {
                                        DispatchQueue.main.async {
                                            completionHandler(SkinImageRespone.init(result: true, message: "下载图片成功", skinName: skinName, image: resultImage, imageSource: .network))
                                        }
                                    }else{
                                        DispatchQueue.main.async {
                                            completionHandler(SkinImageRespone.init(result: false, message: "下载图片读取出错", skinName: skinName, image: nil, imageSource: .network))
                                        }
                                    }
                                break
                                case .failure(let error):
                                    SkinLog("皮肤包：\(skinName)，下载在线图片出错：\(error.localizedDescription)，\nkey= \(key)")
                                    DispatchQueue.main.async {
                                        completionHandler(SkinImageRespone.init(result: false, message: error.localizedDescription, skinName: skinName, image: nil, imageSource: .network))
                                    }
                                break
                            }
                        }
                    }
                }
                else{
                    //只是判断当前皮肤包是否存在指定图片，无需下载，只需返回空图片即可
                    image = nil
                    completionHandler(SkinImageRespone.init(result: false, message: "皮肤图片未下载", skinName: skinName, image: image, imageSource: .network))
                }
            }
        }
        
        //降级读取默认皮肤包资源
        if readDefaultValue {
            //不是默认皮肤包，优先返回默认皮肤包的同名资源
            if skinName != CJ_SKIN_DEFAULT_NAME {
                image = _getSkinImageForKey(key: key, skinInfo: CJSkinSwift.defaultSkinInfo(), skinName: CJSkinSwift.defaultSkinName(), readDefaultValue: readDefaultValue, needDownload: needDownload, completionHandler: {r in})
                SkinLog("皮肤包：\(skinName)，图片资源不存在，降级读取 defaultValue，key= \(key) 开始下载")
            }
            //如果已经是默认皮肤包，返回UIImage.init()
            else{
                image = UIImage.init()
                SkinLog("皮肤包：\(skinName)，图片资源不存在，defaultValue取 UIImage.init()，key= \(key) 开始下载")
            }
        }
        
        return image
    }
    private func _imageCacheKey(_ key: String,_ skinName: String)->NSString {
        return "\(skinName)_\(key)" as NSString
    }
    private func _getImageFromLocalPath(imagePath: String, skinName: String, key: String, imageName: String)->UIImage? {
        var image :UIImage?
        var imageFilePath = _imageExists(path: imagePath, imageName: imageName)
        if imageFilePath.isEmpty {
            return nil
        }
        
        if imageFilePath.containsIgnoringCase(find: "@1x.png") ||
            imageFilePath.containsIgnoringCase(find: "@2x.png") ||
            imageFilePath.containsIgnoringCase(find: "@3x.png") {
            imageFilePath = imageFilePath.replacingOccurrences(of: "@1x", with: "")
            imageFilePath = imageFilePath.replacingOccurrences(of: "@2x", with: "")
            imageFilePath = imageFilePath.replacingOccurrences(of: "@3x", with: "")
            image = UIImage.init(contentsOfFile: imageFilePath)
            if image != nil {
                //将图片加入内存缓存
                CJSkinSwift.imageCache()?.setObject(image!, forKey: self._imageCacheKey(key,skinName))
            }
        }
        else{
            do {
                let data = try NSData.init(contentsOf: URL.init(fileURLWithPath: imageFilePath), options: NSData.ReadingOptions.mappedIfSafe)
                image = UIImage.init(data: data as Data, scale: UIScreen.main.scale)
                if image != nil {
                    //将图片加入内存缓存
                    CJSkinSwift.imageCache()?.setObject(image!, forKey: self._imageCacheKey(key,skinName))
                }
            } catch let error {
                image = nil
                //获取沙盒缓存图片失败，删除无效缓存
                self._deleteLocalImageFile(imagePath: imageFilePath)
                SkinLog("皮肤包：\(skinName)，下载在线图片后生成图片失败：\(error.localizedDescription)，\nkey= \(key)")
            }
        }
        return image
    }
    private func _deleteLocalImageFile(imagePath: String) {
        DispatchQueue.global(qos: .unspecified).async {
            var path = URL.init(fileURLWithPath: imagePath)
            var files : [String]?
            files = try? FileManager.default.contentsOfDirectory(atPath: imagePath)
            if files != nil && files!.count == 1 {
                path = path.deletingLastPathComponent()
            }
            do {
                try FileManager.default.removeItem(at: path)
            } catch {
                SkinLog("移除无效图片缓存出错：\(imagePath)")
            }
        }
    }
    private func _imageExists(path: String, imageName: String) ->String {
        let fileManager = FileManager.default
        var isDir : ObjCBool = false
        
        //包含指定url在线下载的图片，以及皮肤压缩包内整体下载的图片两种情况
        if fileManager.fileExists(atPath: path, isDirectory:&isDir) {
            if isDir.boolValue {
//                print("path exists and is a directory.")
                do {
                    var files : [String]
                    try files = FileManager.default.contentsOfDirectory(atPath: path)
                    var imagePath = ""
                    for (_, item) in files.enumerated() {
                        if item.containsIgnoringCase(find: imageName) {
                            imagePath = "\(path)/\(item)"
                            break
                        }
                    }
                    return imagePath
                } catch {
//                    print("path exists and is a empty directory. = \(path)")
                    return ""
                }
            } else {
//                print("path exists and is not a directory. = \(path)")
                return path
            }
        } else {
//            print("path does not exist. = \(path)")
            return ""
        }
    }
}

// MARK: - 下载
internal extension CJSkinTool {
    /// 下载皮肤文件（优先读取本地缓存）
    /// - Parameters:
    ///   - url: 下载url
    ///   - filePath: 自定义缓存路径
    ///   - completionHandler: 请求回调
    /// - Returns: void
    static func download(_ url: String, filePath: String?, completionHandler: @escaping (Result<String, Error>,HTTPURLResponse?) -> Void) -> Void {
        //判断缓存是否存在
        let fileCachePath = searchUrlCachePath(url: url, filePath: filePath)
        if false == fileCachePath.isEmpty {
            completionHandler(.success(fileCachePath),nil)
            return
        }
        
        let destination: DownloadRequest.Destination = { temporaryURL, response in
            /// 缓存路径 ：Library/Caches/CJSkin/自定义缓存路径（如果有的话）/请求url地址MD5/response.suggestedFilename
//            var urlPath: String = (response.url?.absoluteString.md5)!
            var urlPath: String = (url.md5)
            if nil != filePath {
                urlPath = filePath! + "/" + urlPath
            }
            let skinURL = URL.init(fileURLWithPath: SkinCachePath(urlPath,true))
            let fileURL = skinURL.appendingPathComponent(response.suggestedFilename!)
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        AF.download(url, to: destination).cacheResponse(using: ResponseCacher.cache).validate(statusCode: 200..<300).response { response in
            if response.error == nil {
                let filePath = response.fileURL?.path
                DispatchQueue.main.async {
                    completionHandler(.success(filePath!),response.response)
                }
            }else{
                DispatchQueue.global(qos: .unspecified).async {
                    //移除无效缓存
                    if response.fileURL != nil {
                        do {
                            let path = response.fileURL?.deletingLastPathComponent()
                            try FileManager.default.removeItem(at: path!)
                        } catch {
                            SkinLog("移除无效缓存出错：\(String(describing: url))")
                        }
                    }
                    SkinLog(response.error?.errorDescription as Any)
                }
                DispatchQueue.main.async {
                    completionHandler(.failure(response.error!),response.response)
                }
            }
        }
    }
    
    /// 查找指定url是否存在沙盒缓存，默认一个url对应的缓存路径下只会有一份文件，如果存在多个则认为缓存无效并删除
    /// 缓存路径 ：Library/Caches/CJSkin/自定义缓存路径（如果有的话）/请求url地址MD5/response.suggestedFilename
    /// - Parameter url: 请求url
    /// - Parameter filePath: 自定义缓存路径
    /// - Returns: 本地缓存路径
    static func searchUrlCachePath(url: String, filePath: String?)-> String {
        autoreleasepool {
            var urlPath: String = url.md5
            if nil != filePath {
                urlPath = filePath! + "/" + urlPath
            }
            urlPath = SkinCachePath(urlPath, false)
            var filePath = urlPath
            //判断文件夹是否存在
            if true == FileManager.default.fileExists(atPath: urlPath) {
                do {
                    var files : [String]
                    try files = FileManager.default.contentsOfDirectory(atPath: urlPath)
                    if files.count != 1 {
                        CJSkinSwift.clearImageCachePath(urlPath, nil)
                        filePath = ""
                    }else{
                        let fileName: String = files.first!
                        filePath = "\(filePath)/\(fileName)"
                    }
                } catch {
                    filePath = ""
                    CJSkinSwift.clearImageCachePath(urlPath, nil)
                }
            }
            else{
                filePath = ""
            }
            return filePath
        }
    }
}

// MARK: - String扩展
internal extension String {
    /// MARK: - 获取十六进制的值
    func hexValue() -> Int {
        let str = self.uppercased()
        var sum = 0
        for i in str.utf8 {
            sum = sum * 16 + Int(i) - 48 // 0-9 从48开始
            if i >= 65 {                 // A-Z 从65开始，但有初始值10，所以应该是减去55
                sum -= 7
            }
        }
        return sum
    }
    
    /// 获取md5值
    var md5: String {
        let str = self.cString(using: String.Encoding.utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: String.Encoding.utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        CC_MD5(str!, strLen, result)
        let hash = NSMutableString()
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        result.deallocate()
        return hash as String
    }
    
    /// 判断是否为url
    var isUrl: Bool {
        do {
            let dataDetector = try NSDataDetector(types: NSTextCheckingTypes(NSTextCheckingResult.CheckingType.link.rawValue))
            let res = dataDetector.matches(in: self, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, self.count))
            if res.count == 1 && res[0].range.location == 0 && res[0].range.length == self.count {
                return true
            }
        } catch let error {
            SkinLog(error.localizedDescription)
        }
        return false
    }
    
    /// 是否包含指定字符
    func contains(find: String) -> Bool{
        return self.range(of: find) != nil
    }
    func containsIgnoringCase(find: String) -> Bool{
        return self.range(of: find, options: .caseInsensitive) != nil
    }
}
