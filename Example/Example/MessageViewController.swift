//
//  MessageViewController.swift
//  CJSkinSwift
//
//  Created by 练炽金 on 2021/8/16.
//

import UIKit
import CJSkinSwift

func changeSkinSheet(_ viewController: UIViewController) -> Void {
    let sheet = UIAlertController.init(title: "换肤", message: nil, preferredStyle: .actionSheet)
    let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
    sheet.addAction(cancelAction)
    let allSkin = CJSkinSwift.skinPlistInfo().allKeys
    for (_,skinName) in allSkin.enumerated() {
        let action = UIAlertAction(title: (skinName as! String), style: .default) { (action) in
            CJSkinSwift.skinChange(action.title!) { (result, msg) in
                print(msg)
            }
        }
        sheet.addAction(action)
    }
    viewController.present(sheet, animated: true, completion: nil)
}

func alertMag(_ msg: String, _ viewController: UIViewController) -> Void {
    let alert = UIAlertController.init(title: msg, message: nil, preferredStyle: .alert)
    let cancelAction = UIAlertAction(title: "确定", style: .cancel, handler: nil)
    alert.addAction(cancelAction)
    viewController.present(alert, animated: true, completion: nil)
}

class MessageViewController: UIViewController {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var skinButton: UIButton!
    @IBOutlet weak var updateSkinButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //去除毛玻璃效果
        self.navigationController?.navigationBar.isTranslucent = false
        
        let tabBar: UITabBar = self.tabBarController!.tabBar
        let tabBarItem: UITabBarItem = (tabBar.items?.first)!
        self.tabBarItem = tabBarItem
        
        self.refreshSkin = { (weakSelf: NSObject) in
            let wSelf = (weakSelf as! MessageViewController)
            wSelf.view.backgroundColor = SkinColor("view背景色")
            wSelf.navigationController?.navigationBar.setBackgroundImage(SkinImageFromColor("导航背景色"), for: .default)
            wSelf.label.textColor = SkinColor("tab点击高亮色")
            wSelf.label.font = SkinFont("文字一")
            wSelf.label.text = "当前皮肤：" + CJSkinSwift.skinName()
            wSelf.nextButton.setTitleColor(SkinColor("tab点击高亮色"), for: .normal)
            wSelf.skinButton.setTitleColor(SkinColor("tab点击高亮色"), for: .normal)
            wSelf.updateSkinButton.setTitleColor(SkinColor("tab点击高亮色"), for: .normal)
        }
        
//        //换肤示例
//        let button = UIButton.init()
//        button.refreshSkin = { (weakSelf: NSObject) in
//            let wSelf = (weakSelf as! UIButton)
//            wSelf.backgroundColor = SkinColor("背景色")
//            wSelf.titleLabel?.font = SkinFont("标题")
//            //设置图片的渲染模式为展示原图；并且设置afterDownloadRefreshSkinTarget=wSelf，使得在线图片“按钮”、“按钮高亮”下载完成后将回调refreshSkin()进行UI换肤
//            wSelf.setImage(SkinImageRenderingMode("按钮", .alwaysOriginal, wSelf), for: .normal)
//            wSelf.setImage(SkinImageRenderingMode("按钮高亮", .alwaysOriginal, wSelf), for: .highlighted)
//        }
        
    }
    
    @IBAction func nextVC(_ sender: Any) {
        let secondViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Second") as UIViewController
        self.navigationController?.pushViewController(secondViewController, animated: true)
    }
    
    @IBAction func changeSkin(_ sender: Any) {
        changeSkinSheet(self)
    }
    
    @IBAction func updateSkinData(_ sender: Any) {
        let skinInfo: Dictionary = ["皮肤3":[
            "Color": [
                "导航背景色": "0x4169E1",
                "tab背景色": "0xF2F2F2",
                "tab颜色": "0x0000CD",
                "tab点击高亮色": "0x191970",
                "view背景色": "0xB0C4DE"
            ],
            "Image":[
                "top": "https://upload-images.jianshu.io/upload_images/1429982-ad4ed723d3795fac.jpg"
            ],
            "Font":[
                "文字一":[
                    "Name": "Kefa",
                    "Size": "25"
                ]
            ]
        ]]

        CJSkinSwift.updateSkinPlistInfo(skinInfo as NSDictionary) { (result, msg) in
            print(msg)
            if result {
                let str = "更新皮肤信息成功：新增皮肤“皮肤3”"
                alertMag(str, self)
            }else{
                alertMag(msg, self)
            }
        }
    }
    
    
}
