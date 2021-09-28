//
//  WorkViewController.swift
//  CJSkinSwift
//
//  Created by lele8446 on 2021/9/3.
//

import UIKit
import CJSkinSwift

class WorkViewController: UIViewController {
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var changeSkinButton: UIButton!
    lazy var indicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView.init(style: .whiteLarge)
        view.frame = CGRect.init(x: 0, y: 0, width: 80, height: 80)
        view.backgroundColor = UIColor.gray
        view.layer.cornerRadius = 5
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.indicatorView.center = self.view.center
        self.view.addSubview(self.indicatorView)
        self.indicatorView.hidesWhenStopped = true
        
        let tabBar: UITabBar = self.tabBarController!.tabBar
        let tabBarItem: UITabBarItem = (tabBar.items?[1])!
        self.tabBarItem = tabBarItem
        
        self.refreshSkin = { (weakSelf: NSObject) in
            let wSelf = (weakSelf as! WorkViewController)
            wSelf.view.backgroundColor = SkinColor("view背景色")
            wSelf.navigationController?.navigationBar.setBackgroundImage(SkinImageFromColor("导航背景色"), for: .default)
            wSelf.downloadButton.setTitleColor(SkinColor("tab点击高亮色"), for: .normal)
            wSelf.changeSkinButton.setTitleColor(SkinColor("tab点击高亮色"), for: .normal)
            
            self.addRightItem()
        }
    }
    
    func addRightItem() -> Void {
        let skinTool = SkinTool("clear", .skinTypeImage)
        //设置图片渲染模式
        skinTool.imageRenderingMode = .alwaysOriginal
        let image = skinTool.skinValue() as! UIImage
        let rightBtn: UIBarButtonItem = UIBarButtonItem.init(image: image, style: UIBarButtonItem.Style.plain, target: self, action: #selector(clearCache))
        self.navigationItem.rightBarButtonItem = rightBtn
    }
    
    @objc func clearCache() -> Void {
        CJSkinSwift.clearAllSkinImageCache { (result, msg) in
            alertMag(msg,self)
        }
    }

    @IBAction func downloadSkin(_ sender: Any) {
        self.indicatorView.startAnimating()
        
        let url = "https://lele8446infoq.oss-cn-shenzhen.aliyuncs.com/cjskin/CJSkinOnlineZip.zip"
        CJSkinSwift.downloadSkinZip(url: url) { (result, msg) in
            print("下载皮肤：" + msg)
            alertMag(msg,self)
            self.indicatorView.stopAnimating()
        }
    }
    
    @IBAction func changeSkin(_ sender: Any) {
        changeSkinSheet(self)
    }
}
