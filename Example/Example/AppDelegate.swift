//
//  AppDelegate.swift
//  CJSkinSwift
//
//  Created by 练炽金 on 2021/8/16.
//

import UIKit
import CJSkinSwift

//@main
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow.init(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        let mainViewController: UITabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Tab") as! UITabBarController
        window?.rootViewController = mainViewController
        // Override point for customization after application launch.
        
        //总是从MainBundle读取换肤配置
        CJSkinSwift.debugLoadSkinFromMainBundle()
        
        let tabBar: UITabBar = mainViewController.tabBar
        let tabBarItem1: UITabBarItem = (tabBar.items?.first)!
        tabBarItem1.refreshSkin = { (weakSelf : NSObject) in
            let wSelf = (weakSelf as! UITabBarItem)
            var skinTool = SkinTool("tabbar_message_nor", .skinTypeImage)
            //设置图片渲染模式
            skinTool.imageRenderingMode = .alwaysOriginal
            var image = skinTool.skinValue() as! UIImage
            wSelf.image = image
            
            skinTool = SkinTool("tabbar_message_sel", .skinTypeImage)
            skinTool.imageRenderingMode = .alwaysOriginal
            image = skinTool.skinValue() as! UIImage
            wSelf.selectedImage = image
            
            wSelf.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : SkinColor("tab颜色")], for: UIControl.State.normal)
            wSelf.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : SkinColor("tab点击高亮色")], for: UIControl.State.selected)
        }
        
        let tabBarItem2: UITabBarItem = (tabBar.items?[1])!
        tabBarItem2.refreshSkin = { (weakSelf : NSObject) in
            let wSelf = (weakSelf as! UITabBarItem)
            var skinTool = SkinTool("tabbar_work_nor", .skinTypeImage)
            //设置图片渲染模式
            skinTool.imageRenderingMode = .alwaysOriginal
            var image = skinTool.skinValue() as! UIImage
            wSelf.image = image
            
            skinTool = SkinTool("tabbar_work_sel", .skinTypeImage)
            skinTool.imageRenderingMode = .alwaysOriginal
            image = skinTool.skinValue() as! UIImage
            wSelf.selectedImage = image
            
            wSelf.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : SkinColor("tab颜色")], for: UIControl.State.normal)
            wSelf.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : SkinColor("tab点击高亮色")], for: UIControl.State.selected)
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

//    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
//        // Called when a new scene session is being created.
//        // Use this method to select a configuration to create the new scene with.
//        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
//    }
//
//    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
//        // Called when the user discards a scene session.
//        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
//        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
//    }


}

