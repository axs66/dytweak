# dytweak
设置开启方法：双指长按 功能自测

## 1.修改插件注入后的名称：
Makefile第37~48行，DYYY改为dytweak；DYYY.plist改为dytweak.plist

## 2.修改插件名称：
DYYYSettings.xm第2601行@"DYYY"改为@"抖音净化"；
DYYYConstants.h第4~5行#define DYYY_NAME @"DYYY"  #define DYYY_SETTINGS_NAME @"DYYY设置"改为#define DYYY_NAME @"抖音净化"  #define DYYY_SETTINGS_NAME @"抖音净化设置"

## 3.修改插件版本号：
DYYYConstants.h第9~10行2.2-4改为3.0.5；DYYYSettingViewController.m第451行2.2-4 (修改2025-04-14)改为3.0.5 (Axs修改2025-05-12)

## 4.修改署名信息：
DYYYSettingViewController.m中pxx917144686改为Axs（其中第1661行是头像下方信息：pxx917144686改为抖音净化）

## 5.修改仓库信息：
DYYYSettingViewController.m中第2056行"https://github.com/huami1314/dyyy"改为"https://github.com/Axs/dytweak"

## 6.修改关于插件：
DYYYSettings.xm第2550~2560行
showAboutDialog(@"关于抖音净化",
				    @"版本: " DYYY_VERSION_STRING @"\n\n"
				    @"感谢使用抖音净化\n\n"
				    @"感谢huami开源\n\n"
				    @"人妖嘉嘉户口本无人\n\n"
				    @"开源地址 huami1314/DYYY\n\n",
				    nil);
		  };


    
# 注意：
## 1.本次调用PXX的UI文件：全覆盖
## 2.修改声明：
AwemeHeaders.h第344行
@interface DYYYSettingViewController : UIViewController
@end
改为
// 删除这一整段：
/*
@interface DYYYSettingViewController : UIViewController
@end
*/

// 替换为前向声明：
@class DYYYSettingViewController;

## 3.增加头文件：
DYYY.xm第12行在#import "AwemeHeaders.h"后增加#import "DYYYSettingViewController.h"
