# CJSkinSwift 

### 使用说明

```swift
pod  'CJSkinSwift'  #pod导入

//导入换肤模块
import CJSkinSwift
```

#### 一、静态换肤

```swift
let button = UIButton.init()
//设置颜色
button.backgroundColor = SkinColor("背景色")
//设置图片
button.setImage(SkinImage("按钮", nil), for: .normal)
//设置字体
button.titleLabel?.font = SkinFont("标题")
```

#### 二、动态换肤

在NSObject分类的扩展属性 **refreshSkin** 内设置换肤：

```swift
let button = UIButton.init()
button.refreshSkin = { (weakSelf: NSObject) in
    let wSelf = (weakSelf as! UIButton)
    wSelf.backgroundColor = SkinColor("背景色")
    wSelf.titleLabel?.font = SkinFont("标题")
    //设置图片的渲染模式为展示原图；并且设置afterDownloadRefreshSkinTarget=wSelf，使得在线图片“按钮”、“按钮高亮”下载完成后将回调refreshSkin()进行UI换肤
    wSelf.setImage(SkinImageRenderingMode("按钮", .alwaysOriginal, wSelf), for: .normal)
    wSelf.setImage(SkinImageRenderingMode("按钮高亮", .alwaysOriginal, wSelf), for: .highlighted)
}
```

#### 三、皮肤资源说明

换肤资源使用 **CJSkin.plist**（文件名固定）来配置管理换肤信息，CJSkin.plist实质上是一个xml文件，它里面用字典记录了不同皮肤包的资源信息。例如下图所示：当前项目的CJSkin.plist文件内记录了default、skin1、skin2三个皮肤包，每个皮肤包内固定包含 `Color` 颜色、`Image` 图片、`Font` 字体三类皮肤元素的信息。

注意：CJSkin.plist中 **default** 皮肤包名，资源key： **Color** 、**Image** 、**Font** 以及Font中的 **Name**、**Size** 这些key值的名称是固定的，配置时不能写错！

![CJSkin.plist](https://lele8446infoq.oss-cn-shenzhen.aliyuncs.com/cjskin/CJSkinSwift.png)

另外项目中还有 `default.bundle`、 `skin1.bundle`、 `skin2.bundle` 等文件夹，分别用于存储不同皮肤包下各自的图片，并且 **.bundle**文件夹名字要与CJSkin.plist中配置的皮肤包名对应。default.bundle存储的是默认皮肤资源，你也可以不加入default.bundle而是把图片存储在 **Assets.xcassets** 中，但CJSkin.plist中 **default ** 皮肤的配置说明不能缺失。

- 不同皮肤包 **Color** 字典中的key相同值不同：比如default皮肤包中 `导航背景色` 值为0x996666，skin2皮肤包中 `导航背景色` 的值为0x454545。
- **Image** 的说明同理，比如default和skin2皮肤包都在CJSkin.plist中对图片 `top` 进行了配置说明，它们分别指向了不同的在线url；不同皮肤包的图片还可以放到各自的 **.bundle** 文件夹内，同时在CJSkin.plist中声明图片别名。比如skin1.bundle中包含图片top@2x.png、top@3x.png，它在CJSkin.plist的配置为  `{"Image":{"top":"top.png"}} `，也可以CJSkin.plist中不做配置，而是在获取图片的时候key直接等于 **skin1.bundle**文件夹中存储的图片名 **top**。
-  **Font** 的配置说明也是一样，不同皮肤包的key相同，值为包含 **Name、Size** 两个固定key的字典，Name为空则使用系统默认字体，Size表示了字号大小。

![换肤资源管理](https://lele8446infoq.oss-cn-shenzhen.aliyuncs.com/cjskin/%E6%8D%A2%E8%82%A4%E8%B5%84%E6%BA%90%E7%AE%A1%E7%90%862.jpg)



### 组件模块说明

- **CJSkinSwift.swift** 皮肤包信息管理类，可获取当前皮肤包信息、更换皮肤包、删除指定皮肤包、下载并更新皮肤包（下载的json数据结构参照 CJSkin.plist 文件说明）等功能。

- **CJSkinTool.swift** 获取皮肤资源工具类，换肤所需的颜色、图片、字体等只能通过该类转换获取，其中提供了丰富的便捷获取资源方法。

  


### CJSkinSwift换肤流程

![换肤流程](https://lele8446infoq.oss-cn-shenzhen.aliyuncs.com/cjskin/CJSkinSwift%E6%B5%81%E7%A8%8B.jpg)