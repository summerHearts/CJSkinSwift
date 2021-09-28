//
//  SecondViewController.swift
//  CJSkinSwift
//
//  Created by lele8446 on 2021/8/18.
//

import UIKit
import CJSkinSwift

class SecondViewController: UIViewController {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var removeSkinButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "删除皮肤"

        self.refreshSkin = { (weakSelf: NSObject) in
            let wSelf = (weakSelf as! SecondViewController)
            
            let skinTool = SkinTool("nav_back", .skinTypeImage)
            //设置图片渲染模式
            skinTool.imageRenderingMode = .alwaysOriginal
            let image = skinTool.skinValue() as! UIImage
            let backBtn: UIBarButtonItem = UIBarButtonItem.init(image: image, style: UIBarButtonItem.Style.plain, target: self, action: #selector(wSelf.back))
            wSelf.navigationItem.leftBarButtonItem = backBtn
            
            wSelf.label.textColor = SkinColor("tab点击高亮色")
            wSelf.label.font = SkinFont("详情")
            wSelf.button.setTitleColor(SkinColor("tab点击高亮色"), for: .normal)
            wSelf.removeSkinButton.setTitleColor(SkinColor("tab点击高亮色"), for: .normal)
        }
        
        imageView.refreshSkin = { (weakSelf: NSObject) in
            (weakSelf as! UIImageView).image = SkinImage("top", weakSelf)
        }
    }
    
    @objc func back()-> Void {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func changeSkin(_ sender: Any) {
        changeSkinSheet(self)
    }
    
    @IBAction func removeSkin(_ sender: Any) {
        self.removeSkinSheet()
    }
    
    func removeSkinSheet() -> Void {
        let sheet = UIAlertController.init(title: "换肤", message: nil, preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        sheet.addAction(cancelAction)
        let allSkin = CJSkinSwift.skinPlistInfo().allKeys
        for (_,skinName) in allSkin.enumerated() {
            let action = UIAlertAction(title: (skinName as! String), style: .default) { (action) in
                CJSkinSwift.removeSkin(action.title!) { (result, msg) in
                    print(msg)
                    alertMag(msg,self)
                }
            }
            sheet.addAction(action)
        }
        self.present(sheet, animated: true, completion: nil)
    }
}
