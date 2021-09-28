#
#  Be sure to run `pod spec lint CJLabel.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "CJSkinSwift"
  s.module_name  = "CJSkinSwift"
  s.version      = "1.0.0"
  s.summary      = "CJSkinSwift换肤框架，支持颜色、图片、字体等元素的动态切换."
  s.homepage     = "https://github.com/lele8446/CJImageView"
  # s.license      = "MIT"
  s.license      = { :type => 'Apache License, Version 2.0', :text => <<-LICENSE
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    LICENSE
  }
  s.author       = { "ChiJinLian" => "lele8446@foxmail.com" }
  s.platform     = :ios, "10.0"
  s.source       = { :git => "https://github.com/lele8446/CJImageView.git", :tag => "#{s.version}" }
  s.source_files  = "CJSkinSwift/Classes/*"
  s.swift_version = '5'
  # s.swift_versions = ['5.1', '5.2', '5.3']
  
  s.dependency 'Alamofire', '>= 5.0.0'
  s.dependency 'SSZipArchive'
end
