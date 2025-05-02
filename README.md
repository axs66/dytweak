# DY
设置开启方法：双指长按 功能自测

1.Makefile：
Makefile 通常是管理构建过程的文件。它定义了如何从源代码构建项目、生成 .deb 包等。因此，Makefile 很有可能包含修改 .deb 包具体功能的规则和指令，比如如何生成不同的包、设置包的安装目录、依赖关系等。

2.DYYY.xm： 第15行修改版本号

.xm 文件通常与 Theos 构建系统相关，它是一个脚本文件，定义了如何构建 tweak 或者其他插件。如果你使用的是 Theos 编译工具，那么这个文件可能也包含了与 .deb 包生成相关的功能，比如如何定义包的内容、目标设备等。

3.control：
control 文件是 Debian 包的标准文件，定义了 .deb 包的元数据，包括包的名称、版本、依赖关系、描述等。虽然它主要用于描述包的信息，但它也可以影响 .deb 包的安装和功能。你可以在此文件中设置依赖、说明等内容。

4.DYYYSettingViewController.h（头文件）   第56行插件名称
这个文件通常用于声明类的接口，定义类的属性、方法和一些必要的协议。
它可能包含视图控制器的属性（如 UI 元素）和方法（如处理按钮点击、设置数据等）。
文件中会声明该视图控制器将如何与其他对象交互，以及提供哪些方法来操作视图或响应用户输入。

5.DYYYSettingViewController.m（实现文件）：第262行修改插件版本号，作者信息

这个文件是 DYYYSettingViewController.h 中声明的接口的实现文件，包含了实际的业务逻辑。
这里实现了视图控制器的生命周期方法（如 viewDidLoad, viewWillAppear）和用户交互方法（如按钮点击事件的处理）。

6.DYYYSettings.xm：第343行修改导航名称，第423行修改版本号，第1380行修改个人信息
（设置描述文件）


备注	归属文件	目标位置	原代码	修改代码
修改插件注入后的名称	Makefile	第37~48行	DYYY	dytweak
	plist	名字调整	DYYY.plist	dytweak.plist
修改插件名称	DYYYSettings.xm	第2601行	newSection.sectionHeaderTitle = @"DYYY";  	newSection.sectionHeaderTitle = @"抖音净化" ;  
	DYYYConstants.h	第4~5行	"#define DYYY_NAME @""DYYY""
#define DYYY_SETTINGS_NAME @""DYYY设置"""	"#define DYYY_NAME @""抖音净化""
#define DYYY_SETTINGS_NAME @""抖音净化设置"""
修改插件版本号	DYYYConstants.h	第9~10行	"#define DYYY_VERSION @""2.2-4""
#define DYYY_VERSION_STRING @""v2.2-4"""	"#define DYYY_VERSION @""3.0.5""
#define DYYY_VERSION_STRING @""v3.0.5"""
	DYYYSettingViewController.m	第451行	 self.footerLabel.text = @"Developer By @huamidev\nVersion: 2.2-4 (修改2025-04-14)";	 self.footerLabel.text = @"Developer By @huamidev\nVersion: 3.0.5 (Axs修改2025-05-12)";
修改仓库信息	DYYYSettingViewController.m	第2056行	NSString *githubURL = @"https://github.com/huami1314/dyyy";	NSString *githubURL = @"https://github.com/Axs/dytweak";
	DYYYSettingViewController.m	第207行	self.avatarTapLabel.text = customTapText.length > 0 ? customTapText : @"pxx917144686";	self.avatarTapLabel.text = customTapText.length > 0 ? customTapText : @"Axs";
修改头像名字	DYYYSettingViewController.m	第396行	 [DYYYSettingItem itemWithTitle:@"头像文本-修改" key:@"DYYYAvatarTapText" type:DYYYSettingItemTypeTextField placeholder:@"pxx917144686"],	 [DYYYSettingItem itemWithTitle:@"头像文本-修改" key:@"DYYYAvatarTapText" type:DYYYSettingItemTypeTextField placeholder:@"抖音净化"],
	DYYYSettingViewController.m	第1666行	self.avatarTapLabel.text = textField.text.length > 0 ? textField.text : @"pxx917144686";	self.avatarTapLabel.text = textField.text.length > 0 ? textField.text : @"Axs";
	DYYYSettingViewController.m	第1881行	self.avatarTapLabel.text = @"pxx917144686";	self.avatarTapLabel.text = @"Axs";
修改头像名字	DYYYSettingViewController.m	第2045行	self.avatarTapLabel.text = @"pxx917144686";	self.avatarTapLabel.text = @"Axs";
修改关于插件	DYYYSettings.xm	第2550~2560行		"showAboutDialog(@""关于抖音净化"",
				    @""版本: "" DYYY_VERSION_STRING @""\n\n""
				    @""感谢使用抖音净化\n\n""
				    @""感谢huami开源\n\n""
				    @""Telegram @wxfx8\n\n""
				    @""开源地址 huami1314/DYYY\n\n"",
				    nil);
		  };"
![Uploading image.png…]()

