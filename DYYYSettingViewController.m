#import "DYYYSettingViewController.h"
#import "DYYYManager.h"
#import <Photos/Photos.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, DYYYSettingItemType) {
    DYYYSettingItemTypeSwitch,
    DYYYSettingItemTypeTextField,
    DYYYSettingItemTypeSpeedPicker,
    DYYYSettingItemTypeColorPicker
};

typedef NS_ENUM(NSInteger, DYYYButtonSize) {
    DYYYButtonSizeSmall = 0,
    DYYYButtonSizeMedium = 1,
    DYYYButtonSizeLarge = 2
};

@interface DYYYSettingItem : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) DYYYSettingItemType type;
@property (nonatomic, copy, nullable) NSString *placeholder;

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(DYYYSettingItemType)type;
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(DYYYSettingItemType)type placeholder:(nullable NSString *)placeholder;

@end

@implementation DYYYSettingItem

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(DYYYSettingItemType)type {
    return [self itemWithTitle:title key:key type:type placeholder:nil];
}

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(DYYYSettingItemType)type placeholder:(nullable NSString *)placeholder {
    DYYYSettingItem *item = [[DYYYSettingItem alloc] init];
    item.title = title;
    item.key = key;
    item.type = type;
    item.placeholder = placeholder;
    return item;
}

@end

@interface DYYYSettingViewController () <UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UISearchBarDelegate
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
, UIColorPickerViewControllerDelegate
#endif
>

@property (nonatomic, strong) UIImpactFeedbackGenerator *feedbackGenerator;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSArray<DYYYSettingItem *> *> *settingSections;
@property (nonatomic, strong) NSArray<NSArray<DYYYSettingItem *> *> *filteredSections;
@property (nonatomic, strong) NSMutableArray<NSString *> *filteredSectionTitles;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) NSMutableArray<NSString *> *sectionTitles;
@property (nonatomic, strong) NSMutableSet *expandedSections;
@property (nonatomic, strong) UIView *backgroundColorView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UIView *avatarContainerView;
@property (nonatomic, strong) UILabel *avatarTapLabel;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) BOOL isKVOAdded;

// 添加缺少的方法声明
- (void)resetButtonTapped:(UIButton *)sender;
- (void)showImagePickerForCustomAlbum;
- (void)showImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType forCustomAlbum:(BOOL)isCustomAlbum;
// 新增声明
- (void)showSourceCodePopup;

@end

@implementation DYYYSettingViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DYYY设置";
    self.expandedSections = [NSMutableSet set];
    self.isSearching = NO;
    self.isKVOAdded = NO;
    
    // 初始化触觉反馈生成器
    self.feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self.feedbackGenerator prepare];
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(backButtonTapped:)];
    self.navigationItem.leftBarButtonItem = backItem;
    
    [self setupAppearance];
    [self setupBackgroundColorView];
    [self setupAvatarView];
    [self setupSearchBar];
    [self setupTableView];
    [self setupSettingItems];
    [self setupSectionTitles];
    [self setupFooterLabel];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBackgroundColorChanged) name:@"DYYYBackgroundColorChanged" object:nil];
    
    // 设置链接解析的默认值
    NSString *interfaceDownload = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (interfaceDownload == nil || [interfaceDownload stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
        [[NSUserDefaults standardUserDefaults] setObject:@"https://api.qsy.ink/api/douyin?url=" forKey:@"DYYYInterfaceDownload"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)backButtonTapped:(id)sender {
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.isSearching = NO;
    self.searchBar.text = @"";
    self.filteredSections = nil;
    self.filteredSectionTitles = nil;
    [self.expandedSections removeAllObjects];
    
    if (self.tableView && [self.tableView numberOfSections] > 0) {
        @try {
            [self.tableView reloadData];
        } @catch (NSException *exception) {
        }
    }
    
    if (self.isKVOAdded && self.tableView) {
        @try {
            [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
            self.isKVOAdded = NO;
        } @catch (NSException *exception) {
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (self.isKVOAdded && self.tableView) {
        @try {
            [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
            self.isKVOAdded = NO;
        } @catch (NSException *exception) {
        }
    }
}

#pragma mark - Setup Methods

- (void)setupAppearance {
    if (self.navigationController) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
        self.navigationController.navigationBar.translucent = YES;
        self.navigationController.navigationBar.backgroundColor = [UIColor clearColor];
        self.navigationController.navigationBar.tintColor = [UIColor systemBlueColor];
    }
}

- (void)setupBackgroundColorView {
    self.backgroundColorView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.backgroundColorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    UIColor *savedColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor whiteColor]; // 默认白色
    self.backgroundColorView.backgroundColor = savedColor;
    [self.view insertSubview:self.backgroundColorView atIndex:0];
}

- (void)setupAvatarView {
    self.avatarContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 160)];
    self.avatarContainerView.backgroundColor = [UIColor clearColor];
    
    self.avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 100) / 2, 20, 100, 100)];
    self.avatarImageView.layer.cornerRadius = 50;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.backgroundColor = [UIColor systemGray4Color];
    
    NSString *avatarPath = [self avatarImagePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:avatarPath]) {
        self.avatarImageView.image = [UIImage imageWithContentsOfFile:avatarPath];
    } else {
        self.avatarImageView.image = [UIImage systemImageNamed:@"person.circle.fill"];
        self.avatarImageView.tintColor = [UIColor systemGrayColor];
    }
    
    [self.avatarContainerView addSubview:self.avatarImageView];
    
    self.avatarTapLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 120, self.view.bounds.size.width, 30)];
    NSString *customTapText = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYAvatarTapText"];
    self.avatarTapLabel.text = customTapText.length > 0 ? customTapText : @"Axs";
    self.avatarTapLabel.textAlignment = NSTextAlignmentCenter;
    self.avatarTapLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    self.avatarTapLabel.textColor = [UIColor systemBlueColor];
    [self.avatarContainerView addSubview:self.avatarTapLabel];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapped:)];
    self.avatarImageView.userInteractionEnabled = YES;
    [self.avatarImageView addGestureRecognizer:tapGesture];
}

- (void)setupSearchBar {
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索设置";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.backgroundColor = [UIColor clearColor];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.sectionHeaderTopPadding = 20;
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 204)];
    [self.tableView.tableHeaderView addSubview:self.avatarContainerView];
    [self.tableView.tableHeaderView addSubview:self.searchBar];
    self.searchBar.frame = CGRectMake(0, 160, self.view.bounds.size.width, 44);
    [self.view addSubview:self.tableView];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.tableView addGestureRecognizer:longPress];
}

- (void)setupSettingItems {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<NSArray<DYYYSettingItem *> *> *sections = @[
            @[
                [DYYYSettingItem itemWithTitle:@"启用弹幕改色" key:@"DYYYEnableDanmuColor" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"自定弹幕颜色" key:@"DYYYdanmuColor" type:DYYYSettingItemTypeTextField placeholder:@"十六进制"],
                [DYYYSettingItem itemWithTitle:@"显示进度时长" key:@"DYYYisShowScheduleDisplay" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"进度纵轴位置" key:@"DYYYTimelineVerticalPosition" type:DYYYSettingItemTypeTextField placeholder:@"-12.5"],
                [DYYYSettingItem itemWithTitle:@"进度标签颜色" key:@"DYYYProgressLabelColor" type:DYYYSettingItemTypeTextField placeholder:@"十六进制"],
                [DYYYSettingItem itemWithTitle:@"隐藏视频进度" key:@"DYYYHideVideoProgress" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"启用自动播放" key:@"DYYYisEnableAutoPlay" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"推荐过滤直播" key:@"DYYYisSkipLive" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"推荐过滤热点" key:@"DYYYisSkipHotSpot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"推荐过滤低赞" key:@"DYYYfilterLowLikes" type:DYYYSettingItemTypeTextField placeholder:@"填0关闭"],
                [DYYYSettingItem itemWithTitle:@"推荐过滤文案" key:@"DYYYfilterKeywords" type:DYYYSettingItemTypeTextField placeholder:@"不填关闭"],
                [DYYYSettingItem itemWithTitle:@"推荐视频时限" key:@"DYYYfiltertimelimit" type:DYYYSettingItemTypeTextField placeholder:@"填0关闭，单位为天"],
                [DYYYSettingItem itemWithTitle:@"启用首页净化" key:@"DYYYisEnablePure" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"启用首页全屏" key:@"DYYYisEnableFullScreen" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"屏蔽检测更新" key:@"DYYYNoUpdates" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"去青少年弹窗" key:@"DYYYHideteenmode" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区毛玻璃" key:@"DYYYisEnableCommentBlur" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"通知玻璃效果" key:@"DYYYEnableNotificationTransparency" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"毛玻璃透明度" key:@"DYYYCommentBlurTransparent" type:DYYYSettingItemTypeTextField placeholder:@"0-1小数"],
                [DYYYSettingItem itemWithTitle:@"通知圆角半径" key:@"DYYYNotificationCornerRadius" type:DYYYSettingItemTypeTextField placeholder:@"默认12"],
                [DYYYSettingItem itemWithTitle:@"时间标签颜色" key:@"DYYYLabelColor" type:DYYYSettingItemTypeTextField placeholder:@"十六进制"],
                [DYYYSettingItem itemWithTitle:@"隐藏系统顶栏" key:@"DYYYisHideStatusbar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"关注二次确认" key:@"DYYYfollowTips" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"收藏二次确认" key:@"DYYYcollectTips" type:DYYYSettingItemTypeSwitch],
            ],
            @[
                [DYYYSettingItem itemWithTitle:@"设置顶栏透明" key:@"DYYYtopbartransparent" type:DYYYSettingItemTypeTextField placeholder:@"0-1小数"],
                [DYYYSettingItem itemWithTitle:@"设置全局透明" key:@"DYYYGlobalTransparency" type:DYYYSettingItemTypeTextField placeholder:@"0-1小数"],
                [DYYYSettingItem itemWithTitle:@"首页头像透明" key:@"DYYYAvatarViewTransparency" type:DYYYSettingItemTypeTextField placeholder:@"0-1小数"],
                [DYYYSettingItem itemWithTitle:@"右侧栏缩放度" key:@"DYYYElementScale" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"昵称文案缩放" key:@"DYYYNicknameScale" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"昵称下移距离" key:@"DYYYNicknameVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"文案下移距离" key:@"DYYYDescriptionVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"属地下移距离" key:@"DYYYIPLabelVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置首页标题" key:@"DYYYIndexTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置朋友标题" key:@"DYYYFriendsTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置消息标题" key:@"DYYYMsgTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置我的标题" key:@"DYYYSelfTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"]
            ],
            @[
                [DYYYSettingItem itemWithTitle:@"隐藏全屏观看" key:@"DYYYisHiddenEntry" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏商城" key:@"DYYYHideShopButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏消息" key:@"DYYYHideMessageButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏朋友" key:@"DYYYHideFriendsButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏加号" key:@"DYYYisHiddenJia" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏红点" key:@"DYYYisHiddenBottomDot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏背景" key:@"DYYYisHiddenBottomBg" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏侧栏红点" key:@"DYYYisHiddenSidebarDot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏发作品框" key:@"DYYYHidePostView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏头像加号" key:@"DYYYHideLOTAnimationView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏点赞数值" key:@"DYYYHideLikeLabel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论数值" key:@"DYYYHideCommentLabel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏收藏数值" key:@"DYYYHideCollectLabel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏分享数值" key:@"DYYYHideShareLabel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏点赞按钮" key:@"DYYYHideLikeButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论按钮" key:@"DYYYHideCommentButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏收藏按钮" key:@"DYYYHideCollectButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏头像按钮" key:@"DYYYHideAvatarButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏音乐按钮" key:@"DYYYHideMusicButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏分享按钮" key:@"DYYYHideShareButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏视频定位" key:@"DYYYHideLocation" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏右上搜索" key:@"DYYYHideDiscover" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏相关搜索" key:@"DYYYHideInteractionSearch" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏进入直播" key:@"DYYYHideEnterLive" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论视图" key:@"DYYYHideCommentViews" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏通知提示" key:@"DYYYHidePushBanner" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏头像列表" key:@"DYYYisHiddenAvatarList" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏头像气泡" key:@"DYYYisHiddenAvatarBubble" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏左侧边栏" key:@"DYYYisHiddenLeftSideBar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏吃喝玩乐" key:@"DYYYHideNearbyCapsuleView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏弹幕按钮" key:@"DYYYHideDanmuButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏取消静音" key:@"DYYYHideCancelMute" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏去汽水听" key:@"DYYYHideQuqishuiting" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏共创头像" key:@"DYYYHideGongChuang" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏热点提示" key:@"DYYYHideHotspot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏推荐提示" key:@"DYYYHideRecommendTips" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏分享提示" key:@"DYYYHideShareContentView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏作者声明" key:@"DYYYHideAntiAddictedNotice" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底部相关" key:@"DYYYHideBottomRelated" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏拍摄同款" key:@"DYYYHideFeedAnchorContainer" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏挑战贴纸" key:@"DYYYHideChallengeStickers" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏校园提示" key:@"DYYYHideTemplateTags" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏作者店铺" key:@"DYYYHideHisShop" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏关注直播" key:@"DYYYHideConcernCapsuleView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏顶栏横线" key:@"DYYYHidentopbarprompt" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏视频合集" key:@"DYYYHideTemplateVideo" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏短剧合集" key:@"DYYYHideTemplatePlaylet" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏动图标签" key:@"DYYYHideLiveGIF" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏笔记标签" key:@"DYYYHideItemTag" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底部话题" key:@"DYYYHideTemplateGroup" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏相机定位" key:@"DYYYHideCameraLocation" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏视频滑条" key:@"DYYYHideStoryProgressSlide" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏图片滑条" key:@"DYYYHideDotsIndicator" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏分享私信" key:@"DYYYHidePrivateMessages" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏昵称右侧" key:@"DYYYHideRightLable" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏群聊商店" key:@"DYYYHideGroupShop" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播胶囊" key:@"DYYYHideLiveCapsuleView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏关注顶端" key:@"DYYYHidenLiveView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏同城顶端" key:@"DYYYHideMenuView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏群直播中" key:@"DYYYGroupLiving" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏群工具栏" key:@"DYYYHideGroupInputActionBar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播广场" key:@"DYYYHideLivePlayground" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏礼物展馆" key:@"DYYYHideGiftPavilion" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏顶栏红点" key:@"DYYYHideTopBarBadge" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏退出清屏" key:@"DYYYHideLiveRoomClear" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏投屏按钮" key:@"DYYYHideLiveRoomMirroring" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播发现" key:@"DYYYHideLiveDiscovery" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播点歌" key:@"DYYYHideKTVSongIndicator" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏流量提醒" key:@"DYYYHideCellularAlert" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"聊天评论透明" key:@"DYYYHideChatCommentBg" type:DYYYSettingItemTypeSwitch]
            ],
            @[
                [DYYYSettingItem itemWithTitle:@"移除推荐" key:@"DYYYHideHotContainer" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除关注" key:@"DYYYHideFollow" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除精选" key:@"DYYYHideMediumVideo" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除商城" key:@"DYYYHideMall" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除朋友" key:@"DYYYHideFriend" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除同城" key:@"DYYYHideNearby" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除团购" key:@"DYYYHideGroupon" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除直播" key:@"DYYYHideTabLive" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除热点" key:@"DYYYHidePadHot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除经验" key:@"DYYYHideHangout" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除短剧" key:@"DYYYHidePlaylet" type:DYYYSettingItemTypeSwitch]
            ],
            @[
                [DYYYSettingItem itemWithTitle:@"启用新版玻璃面板" key:@"DYYYisEnableModern" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"启用保存他人头像" key:@"DYYYEnableSaveAvatar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"禁用点击首页刷新" key:@"DYYYDisableHomeRefresh" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"禁用双击视频点赞" key:@"DYYYDouble" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-双击触发" key:@"DYYYEnableDoubleOpenComment" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-长按复制文本" key:@"DYYYEnableCommentCopyText" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-保存动态图" key:@"DYYYCommentLivePhotoNotWaterMark" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-保存图片" key:@"DYYYCommentNoWaterMark" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-保存表情包" key:@"DYYYForceDownloadEmotion" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"视频-显示日期时间" key:@"DYYYShowDateTime" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -年-月-日 时:分" key:@"DYYYDateTimeFormat_YMDHM" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -月-日 时:分" key:@"DYYYDateTimeFormat_MDHM" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -时:分:秒" key:@"DYYYDateTimeFormat_HMS" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -时:分" key:@"DYYYDateTimeFormat_HM" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -年-月-日" key:@"DYYYDateTimeFormat_YMD" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"属地前缀" key:@"DYYYLocationPrefix" type:DYYYSettingItemTypeTextField placeholder:@"IP : "],
                [DYYYSettingItem itemWithTitle:@"时间属地显示-开关" key:@"DYYYisEnableArea" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -省级" key:@"DYYYisEnableAreaProvince" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -城市" key:@"DYYYisEnableAreaCity" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -市区或县城" key:@"DYYYisEnableAreaDistrict" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -街道或小区" key:@"DYYYisEnableAreaStreet" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"链接解析" key:@"DYYYInterfaceDownload" type:DYYYSettingItemTypeTextField placeholder:@"不设置，默认"],
                [DYYYSettingItem itemWithTitle:@"清晰度" key:@"DYYYShowAllVideoQuality" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"屏蔽广告" key:@"DYYYNoAds" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"头像文本-修改" key:@"DYYYAvatarTapText" type:DYYYSettingItemTypeTextField placeholder:@"Axs"],
                [DYYYSettingItem itemWithTitle:@"菜单背景颜色" key:@"DYYYBackgroundColor" type:DYYYSettingItemTypeColorPicker],
                [DYYYSettingItem itemWithTitle:@"默认倍速" key:@"DYYYDefaultSpeed" type:DYYYSettingItemTypeSpeedPicker placeholder:@"点击选择"],
                [DYYYSettingItem itemWithTitle:@"倍速按钮-开关" key:@"DYYYEnableFloatSpeedButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"倍速数值" key:@"DYYYSpeedSettings" type:DYYYSettingItemTypeTextField placeholder:@"英文逗号分隔"],
                [DYYYSettingItem itemWithTitle:@"自动恢复默认倍速" key:@"DYYYAutoRestoreSpeed" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"倍速按钮显示后缀" key:@"DYYYSpeedButtonShowX" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"倍速按钮大小" key:@"DYYYSpeedButtonSize" type:DYYYSettingItemTypeTextField placeholder:@"默认40"],
                [DYYYSettingItem itemWithTitle:@"视频清屏隐藏-开关" key:@"DYYYEnableFloatClearButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -小图标" key:@"DYYYCustomAlbumSizeSmall" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -中图标" key:@"DYYYCustomAlbumSizeMedium" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -大图标" key:@"DYYYCustomAlbumSizeLarge" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"图标更换-开关" key:@"DYYYEnableCustomAlbum" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -本地相册" key:@"DYYYCustomAlbumImage" type:DYYYSettingItemTypeTextField placeholder:@"点击选择图片"],
                [DYYYSettingItem itemWithTitle:@"长按下载功能-开关" key:@"DYYYLongPressDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -视频" key:@"DYYYLongPressVideoDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -音频弹出分享" key:@"DYYYLongPressAudioDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -图片" key:@"DYYYLongPressImageDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -实况动图" key:@"DYYYLongPressLivePhotoDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"长按面板-复制功能" key:@"DYYYCopyText" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -复制原文本" key:@"DYYYCopyOriginalText" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -复制分享链接" key:@"DYYYCopyShareLink" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"双击操作-开关" key:@"DYYYEnableDoubleOpenAlertController" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -保存视频/图片/实况动图" key:@"DYYYDoubleTapDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -音频弹出分享" key:@"DYYYDoubleTapDownloadAudio" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -复制文案" key:@"DYYYDoubleTapCopyDesc" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -打开评论" key:@"DYYYDoubleTapComment" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -点赞视频" key:@"DYYYDoubleTapLike" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -分享视频" key:@"DYYYDoubleTapshowSharePanel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -长按面板" key:@"DYYYDoubleTapshowDislikeOnVideo" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -接口解析" key:@"DYYYDoubleInterfaceDownload" type:DYYYSettingItemTypeSwitch]
            ],
            @[
                [DYYYSettingItem itemWithTitle:@"自定义功能开关" key:@"DYYYEnableSocialStatsCustom" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -粉丝数量" key:@"DYYYCustomFollowers" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -获赞数量" key:@"DYYYCustomLikes" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -关注数量" key:@"DYYYCustomFollowing" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -互关数量" key:@"DYYYCustomMutual" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"]
            ],
            @[
                [DYYYSettingItem itemWithTitle:@"启用快捷倍速按钮" key:@"DYYYEnableFloatSpeedButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"快捷倍速数值设置" key:@"DYYYSpeedSettings" type:DYYYSettingItemTypeTextField placeholder:@"逗号分隔"],
                [DYYYSettingItem itemWithTitle:@"自动恢复默认倍速" key:@"DYYYAutoRestoreSpeed" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"倍速按钮显示后缀" key:@"DYYYSpeedButtonShowX" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"快捷倍速按钮大小" key:@"DYYYSpeedButtonSize" type:DYYYSettingItemTypeTextField placeholder:@"默认32"],
                [DYYYSettingItem itemWithTitle:@"启用一键清屏按钮" key:@"DYYYEnableFloatClearButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"快捷清屏按钮大小" key:@"DYYYEnableFloatClearButtonSize" type:DYYYSettingItemTypeTextField placeholder:@"默认40"],
                [DYYYSettingItem itemWithTitle:@"清屏移除时间进度" key:@"DYYYEnabshijianjindu" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"清屏隐藏时间进度" key:@"DYYYHideTimeProgress" type:DYYYSettingItemTypeSwitch]
             ]
        ];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.settingSections = sections;
            self.filteredSections = sections;
            self.filteredSectionTitles = [self.sectionTitles mutableCopy];
            if (self.tableView) {
                [self.tableView reloadData];
            }
        });
    });
}

- (void)setupSectionTitles {
    self.sectionTitles = [@[@"基本设置", @"界面设置", @"隐藏设置", @"顶栏移除", @"增强设置", @"伪装数据", @"悬浮按钮"] mutableCopy];
    self.filteredSectionTitles = [self.sectionTitles mutableCopy];
}

- (void)setupFooterLabel {
    // 创建一个容器视图，用于包含文本和按钮
    UIView *footerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 100)];
    
    // 创建文本标签
    self.footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 40)];
    self.footerLabel.text = @"Developer By @huamidev\nVersion: 3.0.5 (Axs修改2025-05-12)";
    self.footerLabel.textAlignment = NSTextAlignmentCenter;
    self.footerLabel.font = [UIFont systemFontOfSize:14];
    self.footerLabel.textColor = [UIColor secondaryLabelColor];
    self.footerLabel.numberOfLines = 2;
    [footerContainer addSubview:self.footerLabel];
    
    // 创建"看看源代码"按钮 - 增强动画效果
    UIButton *sourceCodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    sourceCodeButton.frame = CGRectMake((self.view.bounds.size.width - 200) / 2, 50, 200, 40);
    sourceCodeButton.layer.cornerRadius = 20;
    sourceCodeButton.clipsToBounds = YES;
    sourceCodeButton.tag = 101;
    
    // 创建渐变背景
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = CGRectMake(0, 0, 200, 40);
    gradientLayer.cornerRadius = 20;
    gradientLayer.colors = @[(id)[UIColor systemBlueColor].CGColor, (id)[UIColor systemPurpleColor].CGColor];
    gradientLayer.startPoint = CGPointMake(0, 0.5);
    gradientLayer.endPoint = CGPointMake(1, 0.5);
    [sourceCodeButton.layer insertSublayer:gradientLayer atIndex:0];
    
    // 添加动画效果
    CABasicAnimation *gradientAnimation = [CABasicAnimation animationWithKeyPath:@"colors"];
    gradientAnimation.fromValue = @[(id)[UIColor systemBlueColor].CGColor, (id)[UIColor systemPurpleColor].CGColor];
    gradientAnimation.toValue = @[(id)[UIColor systemPurpleColor].CGColor, (id)[UIColor systemBlueColor].CGColor];
    gradientAnimation.duration = 3.0;
    gradientAnimation.autoreverses = YES;
    gradientAnimation.repeatCount = HUGE_VALF;
    [gradientLayer addAnimation:gradientAnimation forKey:@"gradientAnimation"];
    
    [sourceCodeButton setTitle:@"👉 看看源代码！" forState:UIControlStateNormal];
    [sourceCodeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sourceCodeButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    
    // 添加阴影效果
    sourceCodeButton.layer.shadowColor = [UIColor blackColor].CGColor;
    sourceCodeButton.layer.shadowOffset = CGSizeMake(0, 2);
    sourceCodeButton.layer.shadowRadius = 4;
    sourceCodeButton.layer.shadowOpacity = 0.3;
    
    [sourceCodeButton addTarget:self action:@selector(showSourceCodePopup) forControlEvents:UIControlEventTouchUpInside];
    
    // 添加按下效果
    [sourceCodeButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [sourceCodeButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    
    [footerContainer addSubview:sourceCodeButton];
    
    // 设置容器为表格底部视图
    self.tableView.tableFooterView = footerContainer;
}

#pragma mark - Avatar Handling

- (void)avatarTapped:(UITapGestureRecognizer *)gesture {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == PHAuthorizationStatusAuthorized) {
                UIImagePickerController *picker = [[UIImagePickerController alloc] init];
                picker.delegate = self;
                picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                picker.allowsEditing = YES;
                [self presentViewController:picker animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法访问相册"
                                                                               message:@"请在设置中允许访问相册"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *selectedImage = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if (!selectedImage) {
        [DYYYManager showToast:@"无法获取所选图片"];
        return;
    }
    
    BOOL isCustomAlbumPicker = [objc_getAssociatedObject(picker, "isCustomAlbumPicker") boolValue];
    if (isCustomAlbumPicker) {
        NSString *customAlbumImagePath = [self saveCustomAlbumImage:selectedImage];
        if (customAlbumImagePath) {
            [[NSUserDefaults standardUserDefaults] setObject:customAlbumImagePath forKey:@"DYYYCustomAlbumImagePath"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [DYYYManager showToast:@"自定义相册图片已设置"];
            [self.tableView reloadData];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
        } else {
            [DYYYManager showToast:@"保存自定义相册图片失败"];
        }
    } else {
        NSString *avatarPath = [self avatarImagePath];
        NSData *imageData = UIImageJPEGRepresentation(selectedImage, 0.8);
        [imageData writeToFile:avatarPath atomically:YES];
        self.avatarImageView.image = selectedImage;
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)avatarImagePath {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documentsPath stringByAppendingPathComponent:@"DYYYAvatar.jpg"];
}

- (NSString *)saveCustomAlbumImage:(UIImage *)image {
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolder = [documentsPath stringByAppendingPathComponent:@"DYYY"];
    
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolder 
                              withIntermediateDirectories:YES 
                                               attributes:nil 
                                                    error:&error];
    if (error) {
        return nil;
    }
    
    NSString *imagePath = [dyyyFolder stringByAppendingPathComponent:@"custom_album_image.png"];
    NSData *imageData = UIImagePNGRepresentation(image);
    if ([imageData writeToFile:imagePath atomically:YES]) {
        return imagePath;
    }
    
    return nil;
}

#pragma mark - Color Picker

- (void)showColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
        UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor systemBackgroundColor];
        picker.selectedColor = currentColor;
        picker.delegate = (id)self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择背景颜色"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray<NSDictionary *> *colors = @[
            @{@"name": @"粉红", @"color": [UIColor systemRedColor]},
            @{@"name": @"蓝色", @"color": [UIColor systemBlueColor]},
            @{@"name": @"绿色", @"color": [UIColor systemGreenColor]},
            @{@"name": @"黄色", @"color": [UIColor systemYellowColor]},
            @{@"name": @"紫色", @"color": [UIColor systemPurpleColor]},
            @{@"name": @"橙色", @"color": [UIColor systemOrangeColor]},
            @{@"name": @"粉色", @"color": [UIColor systemPinkColor]},
            @{@"name": @"灰色", @"color": [UIColor systemGrayColor]},
            @{@"name": @"白色", @"color": [UIColor whiteColor]},
            @{@"name": @"黑色", @"color": [UIColor blackColor]}
        ];
        for (NSDictionary *colorInfo in colors) {
            NSString *name = colorInfo[@"name"];
            UIColor *color = colorInfo[@"color"];
            UIAlertAction *action = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                self.backgroundColorView.backgroundColor = color;
                NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
                [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBackgroundColor"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                for (NSInteger section = 0; section < self.settingSections.count; section++) {
                    NSArray *items = self.settingSections[section];
                    for (NSInteger row = 0; row < items.count; row++) {
                        DYYYSettingItem *item = items[row];
                        if (item.type == DYYYSettingItemTypeColorPicker) {
                            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                            if (self.tableView) {
                                [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                            }
                            break;
                        }
                    }
                }
            }];
            UIImage *colorImage = [self imageWithColor:color size:CGSizeMake(20, 20)];
            [action setValue:colorImage forKey:@"image"];
            [alert addAction:action];
        }
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.tableView;
            alert.popoverPresentationController.sourceRect = self.tableView.bounds;
        }
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// 支持 UIColorPickerViewController 回调
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)){
    UIColor *color = viewController.selectedColor;
    self.backgroundColorView.backgroundColor = color;
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
    [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBackgroundColor"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // 通知弹窗刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYBackgroundColorChanged" object:nil];
    for (NSInteger section = 0; section < self.settingSections.count; section++) {
        NSArray *items = self.settingSections[section];
        for (NSInteger row = 0; row < items.count; row++) {
            DYYYSettingItem *item = items[row];
            if (item.type == DYYYSettingItemTypeColorPicker) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                if (self.tableView) {
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                }
                break;
            }
        }
    }
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)){
    [self colorPickerViewControllerDidSelectColor:viewController];
}
#endif

- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [color setFill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, size.width - 2, size.height - 2)];
    path.lineWidth = 1.0;
    [path fill];
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.isSearching = NO;
        self.filteredSections = self.settingSections;
        self.filteredSectionTitles = [self.sectionTitles mutableCopy];
        [self.expandedSections removeAllObjects];
    } else {
        self.isSearching = YES;
        NSMutableArray *filtered = [NSMutableArray array];
        NSMutableArray *filteredTitles = [NSMutableArray array];
        
        for (NSUInteger i = 0; i < self.settingSections.count; i++) {
            NSArray<DYYYSettingItem *> *section = self.settingSections[i];
            NSMutableArray<DYYYSettingItem *> *filteredItems = [NSMutableArray array];
            
            for (DYYYSettingItem *item in section) {
                if ([item.title localizedCaseInsensitiveContainsString:searchText] || 
                    [item.key localizedCaseInsensitiveContainsString:searchText]) {
                    [filteredItems addObject:item];
                }
            }
            
            if (filteredItems.count > 0) {
                [filtered addObject:filteredItems];
                [filteredTitles addObject:self.sectionTitles[i]];
                [self.expandedSections addObject:@(filteredTitles.count - 1)];
            }
        }
        
        self.filteredSections = filtered;
        self.filteredSectionTitles = filteredTitles;
    }
    
    if (self.tableView) {
        [self.tableView reloadData];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.isSearching ? self.filteredSections.count : self.settingSections.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 44)];
    headerView.backgroundColor = [UIColor clearColor];
    
    UIButton *headerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    headerButton.frame = CGRectMake(15, 7, tableView.bounds.size.width - 30, 30);
    headerButton.backgroundColor = [UIColor systemBackgroundColor];
    headerButton.layer.cornerRadius = 10;
    headerButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    headerButton.contentEdgeInsets = UIEdgeInsetsMake(0, 40, 0, 0); // 预留左侧空间给箭头
    headerButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [headerButton setTitle:self.isSearching ? self.filteredSectionTitles[section] : self.sectionTitles[section] forState:UIControlStateNormal];
    [headerButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    headerButton.tag = section;
    [headerButton addTarget:self action:@selector(headerTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    UIImageView *arrowImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:[self.expandedSections containsObject:@(section)] ? @"chevron.down" : @"chevron.right"]];
    // 修改箭头位置到左侧 - 适配各种iPhone机型
    arrowImageView.frame = CGRectMake(25, 12, 20, 20);
    
    // 使用彩色箭头 - 为每个分区分配不同颜色
    UIColor *arrowColor;
    switch (section) {
        case 0:
            arrowColor = [UIColor systemBlueColor]; // 基本设置
            break;
        case 1:
            arrowColor = [UIColor systemPurpleColor]; // 界面设置
            break;
        case 2:
            arrowColor = [UIColor systemRedColor]; // 隐藏设置
            break;
        case 3:
            arrowColor = [UIColor systemOrangeColor]; // 界面设置
            break;
        case 4:
            arrowColor = [UIColor systemGreenColor]; // 增强设置
            break;
        default:
            arrowColor = [UIColor systemTealColor];
            break;
    }
    arrowImageView.tintColor = arrowColor;
    // 添加轻微阴影效果使图标更突出
    arrowImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    arrowImageView.layer.shadowOffset = CGSizeMake(0, 1);
    arrowImageView.layer.shadowOpacity = 0.2;
    arrowImageView.layer.shadowRadius = 1.5;
    arrowImageView.tag = 100;
    [headerView addSubview:headerButton];
    [headerView addSubview:arrowImageView];
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section >= sections.count) {
        return 0;
    }
    return [self.expandedSections containsObject:@(section)] ? sections[section].count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }
    
    DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SettingCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    // 移除旧的重置按钮和其他自定义视图
    for (UIView *view in cell.contentView.subviews) {
        if (view.tag == 555) {
            [view removeFromSuperview];
        }
    }
    
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.text = nil; // 清空，防止复用时异常
    
    // 为单元格添加左侧彩色图标
    UIImage *icon = [self iconImageForSettingItem:item];
    if (icon) {
        cell.imageView.image = icon;
        cell.imageView.tintColor = [self colorForSettingItem:item];
    }

    // 微软风格卡片背景
    UIView *card = [cell.contentView viewWithTag:8888];
    if (!card) {
        card = [[UIView alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 8, 4)];
        card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        card.layer.cornerRadius = 12;
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowOpacity = 0.06;
        card.layer.shadowOffset = CGSizeMake(0, 1);
        card.layer.shadowRadius = 4;
        card.tag = 8888;
        [cell.contentView insertSubview:card atIndex:0];
    }
    
    // 创建单元格的配件视图
    UIView *accessoryView = nil;
    
    if (item.type == DYYYSettingItemTypeSwitch) {
        // 开关类型
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.onTintColor = [UIColor systemBlueColor];
        
        // 处理时间属地显示开关逻辑...
        if ([item.key hasPrefix:@"DYYYisEnableArea"] && 
            ![item.key isEqualToString:@"DYYYisEnableArea"]) {
            // 现有代码...
            BOOL parentEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
            switchView.enabled = parentEnabled;
            
            BOOL isAreaSubSwitch = [item.key isEqualToString:@"DYYYisEnableAreaProvince"] ||
                                  [item.key isEqualToString:@"DYYYisEnableAreaCity"] ||
                                  [item.key isEqualToString:@"DYYYisEnableAreaDistrict"] ||
                                  [item.key isEqualToString:@"DYYYisEnableAreaStreet"];
            
            if (isAreaSubSwitch) {
                // 现有代码...
                BOOL anyEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAreaProvince"] ||
                                [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAreaCity"] ||
                                [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAreaDistrict"] ||
                                [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAreaStreet"];
                
                if (anyEnabled && parentEnabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:item.key];
                    [switchView setOn:YES];
                } else {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:item.key];
                    [switchView setOn:NO];
                }
            } else {
                BOOL isOn = parentEnabled ? [[NSUserDefaults standardUserDefaults] boolForKey:item.key] : NO;
                [switchView setOn:isOn];
            }
        } else {
            [switchView setOn:[[NSUserDefaults standardUserDefaults] boolForKey:item.key]];
        }
        
        [switchView addTarget:self action:@selector(animatedSwitchToggled:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.section * 1000 + indexPath.row;
        accessoryView = switchView;
    } else if (item.type == DYYYSettingItemTypeTextField) {
        // 文本输入类型
        if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
            UIButton *chooseButton = [UIButton buttonWithType:UIButtonTypeSystem];
            [chooseButton setTitle:@"选择图片" forState:UIControlStateNormal];
            [chooseButton addTarget:self action:@selector(showImagePickerForCustomAlbum) forControlEvents:UIControlEventTouchUpInside];
            chooseButton.frame = CGRectMake(0, 0, 80, 30);
            accessoryView = chooseButton;
        } else {
            // 关键：加宽文本框宽度，避免被遮挡
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 160, 30)];
            textField.layer.cornerRadius = 8;
            textField.clipsToBounds = YES;
            textField.backgroundColor = [UIColor tertiarySystemFillColor];
            textField.textColor = [UIColor labelColor];
            textField.placeholder = item.placeholder;
            textField.textAlignment = NSTextAlignmentRight;
            textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:item.key];
            [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingDidEnd];
            textField.tag = indexPath.section * 1000 + indexPath.row;

            accessoryView = textField;

            if ([item.key isEqualToString:@"DYYYAvatarTapText"]) {
                [textField addTarget:self action:@selector(avatarTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            }
        }
    } else if (item.type == DYYYSettingItemTypeSpeedPicker || item.type == DYYYSettingItemTypeColorPicker) {
        // 倍速选择器或颜色选择器类型
        if (item.type == DYYYSettingItemTypeSpeedPicker) {
            UITextField *speedField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
            speedField.text = [NSString stringWithFormat:@"%.2f", [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYDefaultSpeed"]];
            speedField.textColor = [UIColor labelColor];
            speedField.borderStyle = UITextBorderStyleNone;
            speedField.backgroundColor = [UIColor clearColor];
            speedField.textAlignment = NSTextAlignmentRight;
            speedField.enabled = NO;
            speedField.tag = 999;
            accessoryView = speedField;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            // 为菜单背景颜色添加彩色渐变效果
            UIView *colorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
            colorView.layer.cornerRadius = 15;
            colorView.clipsToBounds = YES;
            colorView.layer.borderWidth = 1.0;
            colorView.layer.borderColor = [UIColor whiteColor].CGColor;
            
            // 从 UserDefaults 获取保存的颜色
            NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
            UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor systemBackgroundColor];
            
            // 创建渐变背景展示当前颜色效果
            CAGradientLayer *gradientLayer = [CAGradientLayer layer];
            gradientLayer.frame = colorView.bounds;
            gradientLayer.cornerRadius = 15;
            
            // 使用当前颜色创建渐变效果
            if ([currentColor isEqual:[UIColor whiteColor]] || [currentColor isEqual:[UIColor systemBackgroundColor]]) {
                // 如果是白色或系统背景色，使用彩虹渐变表示取色器
                gradientLayer.colors = @[
                    (id)[UIColor systemRedColor].CGColor,
                    (id)[UIColor systemOrangeColor].CGColor,
                    (id)[UIColor systemYellowColor].CGColor,
                    (id)[UIColor systemGreenColor].CGColor,
                    (id)[UIColor systemBlueColor].CGColor,
                    (id)[UIColor systemPurpleColor].CGColor
                ];
                gradientLayer.startPoint = CGPointMake(0, 0);
                gradientLayer.endPoint = CGPointMake(1, 1);
            } else {
                // 使用选择的颜色进行渐变
                gradientLayer.colors = @[
                    (id)[currentColor colorWithAlphaComponent:0.7].CGColor,
                    (id)currentColor.CGColor,
                    (id)[currentColor colorWithAlphaComponent:0.9].CGColor
                ];
                gradientLayer.startPoint = CGPointMake(0, 0);
                gradientLayer.endPoint = CGPointMake(1, 1);
            }
            
            [colorView.layer insertSublayer:gradientLayer atIndex:0];
            accessoryView = colorView;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    // 设置单元格的配件视图
    if (accessoryView) {
        cell.accessoryView = accessoryView;
    }
    
    return cell;
}

// 根据设置项返回图标名称
- (UIImage *)iconImageForSettingItem:(DYYYSettingItem *)item {
    NSString *iconName;
    
    // 为彩色取色器添加特殊处理
    if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
        iconName = @"paintpalette.fill";
    } 
    // 其他根据设置项的key选择合适的图标...
    else if ([item.key containsString:@"Danmu"] || [item.key containsString:@"弹幕"]) {
        iconName = @"text.bubble.fill";
    } else if ([item.key containsString:@"Color"] || [item.key containsString:@"颜色"]) {
        iconName = @"paintbrush.fill";
    } else if ([item.key containsString:@"Hide"] || [item.key containsString:@"hidden"]) {
        iconName = @"eye.slash.fill";
    } else if ([item.key containsString:@"Download"] || [item.key containsString:@"下载"]) {
        iconName = @"arrow.down.circle.fill";
    } else if ([item.key containsString:@"Video"] || [item.key containsString:@"视频"]) {
        iconName = @"video.fill";
    } else if ([item.key containsString:@"Audio"] || [item.key containsString:@"音频"]) {
        iconName = @"speaker.wave.2.fill";
    } else if ([item.key containsString:@"Image"] || [item.key containsString:@"图片"]) {
        iconName = @"photo.fill";
    } else if ([item.key containsString:@"Speed"] || [item.key containsString:@"倍速"]) {
        iconName = @"speedometer";
    } else if ([item.key containsString:@"Enable"] || [item.key containsString:@"启用"]) {
        iconName = @"checkmark.circle.fill";
    } else if ([item.key containsString:@"Disable"] || [item.key containsString:@"禁用"]) {
        iconName = @"xmark.circle.fill";
    } else if ([item.key containsString:@"Time"] || [item.key containsString:@"时间"]) {
        iconName = @"clock.fill";
    } else if ([item.key containsString:@"Date"] || [item.key containsString:@"日期"]) {
        iconName = @"calendar";
    } else if ([item.key containsString:@"Button"] || [item.key containsString:@"按钮"]) {
        iconName = @"hand.tap.fill";
    } else if ([item.key containsString:@"Avatar"] || [item.key containsString:@"头像"]) {
        iconName = @"person.crop.circle.fill";
    } else if ([item.key containsString:@"Comment"] || [item.key containsString:@"评论"]) {
        iconName = @"message.fill";
    } else if ([item.key containsString:@"Clean"] || [item.key containsString:@"清理"] || [item.key containsString:@"清屏"]) {
        iconName = @"trash.fill";
    } else if ([item.key containsString:@"Share"] || [item.key containsString:@"分享"]) {
        iconName = @"square.and.arrow.up.fill";
    } else if ([item.key containsString:@"Background"] || [item.key containsString:@"背景"]) {
        iconName = @"rectangle.fill.on.rectangle.fill";
    } else if ([item.key containsString:@"Like"] || [item.key containsString:@"点赞"]) {
        iconName = @"heart.fill";
    } else if ([item.key containsString:@"Notification"] || [item.key containsString:@"通知"]) {
        iconName = @"bell.fill";
    } else if ([item.key containsString:@"Copy"] || [item.key containsString:@"复制"]) {
        iconName = @"doc.on.doc.fill";
    } else if ([item.key containsString:@"Text"] || [item.key containsString:@"文本"]) {
        iconName = @"text.alignleft";
    } else if ([item.key containsString:@"Location"] || [item.key containsString:@"位置"] || [item.key containsString:@"属地"]) {
        iconName = @"location.fill";
    } else if ([item.key containsString:@"Area"] || [item.key containsString:@"地区"]) {
        iconName = @"mappin.and.ellipse";
    } else if ([item.key containsString:@"Layout"] || [item.key containsString:@"布局"]) {
        iconName = @"square.grid.2x2.fill";
    } else if ([item.key containsString:@"Transparent"] || [item.key containsString:@"透明"]) {
        iconName = @"square.on.circle.fill";
    } else if ([item.key containsString:@"Live"] || [item.key containsString:@"直播"]) {
        iconName = @"antenna.radiowaves.left.and.right";
    } else if ([item.key containsString:@"Double"] || [item.key containsString:@"双击"]) {
        iconName = @"hand.tap.fill";
    } else if ([item.key containsString:@"Long"] || [item.key containsString:@"长按"]) {
        iconName = @"hand.draw.fill";
    } else if ([item.key containsString:@"ScreenDisplay"] || [item.key containsString:@"全屏"]) {
        iconName = @"rectangle.expand.vertical";
    } else if ([item.key containsString:@"Index"] || [item.key containsString:@"首页"]) {
        iconName = @"house.fill";
    } else if ([item.key containsString:@"Friends"] || [item.key containsString:@"朋友"]) {
        iconName = @"person.2.fill";
    } else if ([item.key containsString:@"Msg"] || [item.key containsString:@"消息"]) {
        iconName = @"envelope.fill";
    } else if ([item.key containsString:@"Self"] || [item.key containsString:@"我的"]) {
        iconName = @"person.crop.square.fill";
    } else if ([item.key containsString:@"NoAds"] || [item.key containsString:@"广告"]) {
        iconName = @"xmark.octagon.fill";
    } else if ([item.key containsString:@"NoUpdates"] || [item.key containsString:@"更新"]) {
        iconName = @"arrow.triangle.2.circlepath";
    } else if ([item.key containsString:@"InterfaceDownload"] || [item.key containsString:@"接口"]) {
        iconName = @"link.circle.fill";
    } else if ([item.key containsString:@"Scale"] || [item.key containsString:@"缩放"]) {
        iconName = @"arrow.up.left.and.down.right.magnifyingglass";
    } else if ([item.key containsString:@"Blur"] || [item.key containsString:@"模糊"] || [item.key containsString:@"玻璃"]) {
        iconName = @"drop.fill";
    } else if ([item.key containsString:@"Shop"] || [item.key containsString:@"商城"]) {
        iconName = @"cart.fill";
    } else if ([item.key containsString:@"Tips"] || [item.key containsString:@"提示"]) {
        iconName = @"exclamationmark.bubble.fill";
    } else if ([item.key containsString:@"Format"] || [item.key containsString:@"格式"]) {
        iconName = @"textformat";
    } else if ([item.key containsString:@"Filter"] || [item.key containsString:@"过滤"]) {
        iconName = @"line.horizontal.3.decrease.circle.fill";
    } else {
        // 默认图标
        iconName = @"gearshape.fill";
    }
    
    UIImage *icon = [UIImage systemImageNamed:iconName];
    if (@available(iOS 15.0, *)) {
        // 为颜色背景特殊处理
        if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
            return [icon imageWithConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:[UIColor systemPinkColor]]];
        }
        return [icon imageWithConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:[self colorForSettingItem:item]]];
    } else {
        return icon;
    }
}

// 根据设置项返回颜色
- (UIColor *)colorForSettingItem:(DYYYSettingItem *)item {
    // 为取色器设置特殊颜色
    if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
        return [UIColor systemPinkColor];
    }
    
    // 根据设置项类型返回不同颜色
    if ([item.key containsString:@"Hide"] || [item.key containsString:@"hidden"]) {
        return [UIColor systemRedColor];
    } else if ([item.key containsString:@"Enable"] || [item.key containsString:@"启用"]) {
        return [UIColor systemGreenColor];
    } else if ([item.key containsString:@"Color"] || [item.key containsString:@"颜色"]) {
        return [UIColor systemPurpleColor];
    } else if ([item.key containsString:@"Double"] || [item.key containsString:@"双击"]) {
        return [UIColor systemOrangeColor];
    } else if ([item.key containsString:@"Download"] || [item.key containsString:@"下载"]) {
        return [UIColor systemBlueColor];
    } else if ([item.key containsString:@"Video"] || [item.key containsString:@"视频"]) {
        return [UIColor systemIndigoColor];
    } else if ([item.key containsString:@"Audio"] || [item.key containsString:@"音频"]) {
        return [UIColor systemTealColor];
    } else if ([item.key containsString:@"Speed"] || [item.key containsString:@"倍速"]) {
        return [UIColor systemYellowColor];
    } else if ([item.key containsString:@"Time"] || [item.key containsString:@"时间"]) {
        return [UIColor systemOrangeColor];
    }
    
    // 默认颜色
    return [UIColor systemBlueColor];
}

// 微软风格UISwitch动画，联动卡片
- (void)animatedSwitchToggled:(UISwitch *)sender {
    UITableViewCell *cell = (UITableViewCell *)sender.superview.superview;
    UIView *card = [cell.contentView viewWithTag:8888];
    // 卡片和switch联动弹跳+高光
    [UIView animateWithDuration:0.10 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.90, 0.90);
        sender.alpha = 0.7;
        sender.layer.shadowColor = [UIColor systemBlueColor].CGColor;
        sender.layer.shadowOpacity = 0.18;
        sender.layer.shadowRadius = 8;
        sender.layer.shadowOffset = CGSizeMake(0, 2);
        card.transform = CGAffineTransformMakeScale(0.97, 0.97);
               card.layer.shadowOpacity =0.18;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.7 options:0 animations:^{
            sender.transform = CGAffineTransformIdentity;
            sender.alpha = 1.0;
            sender.layer.shadowOpacity = 0.0;
            card.transform = CGAffineTransformIdentity;
            card.layer.shadowOpacity = 0.06;
        } completion:nil];
    }];
    [self switchToggled:sender];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat cornerRadius = 10.0;
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:cell.bounds
                                                  byRoundingCorners:(indexPath.row == 0 ? (UIRectCornerTopLeft | UIRectCornerTopRight) : 0) |
                                                                   (indexPath.row == [tableView numberOfRowsInSection:indexPath.section] - 1 ? (UIRectCornerBottomLeft | UIRectCornerBottomRight) : 0)
                                                        cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    cell.layer.mask = maskLayer;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
    if (item.type == DYYYSettingItemTypeSpeedPicker) {
        [self showSpeedPicker];
    } else if (item.type == DYYYSettingItemTypeColorPicker) {
        [self showColorPicker];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)showSpeedPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择倍速"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *speeds = @[@0.75, @1.0, @1.25, @1.5, @2.0, @2.5, @3.0];
    for (NSNumber *speed in speeds) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%.2f", speed.floatValue]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            [[NSUserDefaults standardUserDefaults] setFloat:speed.floatValue forKey:@"DYYYDefaultSpeed"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            for (NSInteger section = 0; section < self.settingSections.count; section++) {
                NSArray *items = self.settingSections[section];
                for (NSInteger row = 0; row < items.count; row++) {
                    DYYYSettingItem *item = items[row];
                    if (item.type == DYYYSettingItemTypeSpeedPicker) {
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                        UITextField *speedField = [cell.accessoryView viewWithTag:999];
                        if (speedField) {
                            speedField.text = [NSString stringWithFormat:@"%.2f", speed.floatValue];
                        }
                        break;
                    }
                }
            }
        }];
        [alert addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:[self.tableView indexPathForSelectedRow]];
        alert.popoverPresentationController.sourceView = selectedCell;
        alert.popoverPresentationController.sourceRect = selectedCell.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Actions

- (void)switchToggled:(UISwitch *)sender {
    // 触发触觉反馈
    [self.feedbackGenerator impactOccurred];
    [self.feedbackGenerator prepare];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:sender.tag % 1000 inSection:sender.tag / 1000];
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
        return;
    }
    
    DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
    BOOL isOn = sender.isOn; // 保存用户切换后的实际值
    
    // 处理时间属地显示开关逻辑...
    if ([item.key hasPrefix:@"DYYYisEnableArea"] && 
        ![item.key isEqualToString:@"DYYYisEnableArea"]) {
        BOOL parentEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
        sender.enabled = parentEnabled;
        
        BOOL isAreaSubSwitch = [item.key isEqualToString:@"DYYYisEnableAreaProvince"] ||
                              [item.key isEqualToString:@"DYYYisEnableAreaCity"] ||
                              [item.key isEqualToString:@"DYYYisEnableAreaDistrict"] ||
                              [item.key isEqualToString:@"DYYYisEnableAreaStreet"];
        
        if (isAreaSubSwitch && !parentEnabled) {
            // 如果父开关关闭，子开关不能打开
            sender.on = NO;
            isOn = NO;
            [DYYYManager showToast:@"请先开启「时间属地显示-开关」"];
            return;
        }
    }
    
    // 检查双击操作开关的父子关系
    if ([item.key hasPrefix:@"DYYYDoubleTap"] && 
        ![item.key isEqualToString:@"DYYYEnableDoubleOpenAlertController"]) {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleOpenAlertController"]) {
            // 如果父级开关关闭，则不允许打开子级设置
            sender.on = NO;
            isOn = NO;
            [DYYYManager showToast:@"请先开启「双击操作-开关」"];
            return;
        }
    }
    
    // 检查长按下载功能的父子开关关系
    if ([item.key isEqualToString:@"DYYYLongPressVideoDownload"] || 
        [item.key isEqualToString:@"DYYYLongPressAudioDownload"] || 
        [item.key isEqualToString:@"DYYYLongPressImageDownload"] ||
        [item.key isEqualToString:@"DYYYLongPressLivePhotoDownload"]) {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressDownload"]) {
            // 如果父级开关关闭，则不允许打开子级设置
            sender.on = NO;
            isOn = NO;
            [DYYYManager showToast:@"请先开启「长按下载功能」"];
            return;
        }
    }
    
    // 检查复制文案功能的父子开关关系
    if ([item.key isEqualToString:@"DYYYCopyOriginalText"] || 
        [item.key isEqualToString:@"DYYYCopyShareLink"]) {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCopyText"]) {
            // 如果父级开关关闭，则不允许打开子级设置
            sender.on = NO;
            isOn = NO;
            [DYYYManager showToast:@"请先开启「复制文案功能」"];
            return;
        }
    }
    
    // 长按下载功能主开关关闭时，关闭所有子开关
    if ([item.key isEqualToString:@"DYYYLongPressDownload"] && !isOn) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYLongPressVideoDownload"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYLongPressAudioDownload"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYLongPressImageDownload"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYLongPressLivePhotoDownload"];
        
        // 刷新界面，更新所有子开关状态
        [self updateSubswitchesForSection:indexPath.section parentKey:@"DYYYLongPressDownload"];
    }
    // 复制文案功能主开关关闭时，关闭所有子开关
    else if ([item.key isEqualToString:@"DYYYCopyText"] && !isOn) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYCopyOriginalText"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYCopyShareLink"];
        
        // 刷新界面，更新所有子开关状态
        [self updateSubswitchesForSection:indexPath.section parentKey:@"DYYYCopyText"];
    }
    
    // 处理日期时间格式开关组
    if ([item.key isEqualToString:@"DYYYShowDateTime"]) {
        // 主开关操作 - 所有子开关跟随主开关状态
        BOOL mainEnabled = isOn;
        [[NSUserDefaults standardUserDefaults] setBool:mainEnabled forKey:@"DYYYShowDateTime"];
        
        // 如果主开关关闭，关闭所有子开关
        if (!mainEnabled) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMDHM"];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_MDHM"];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HMS"];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HM"];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMD"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
        } 
        // 如果主开关打开，默认启用第一个格式
        else if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_YMDHM"] && 
                ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_MDHM"] && 
                ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_HMS"] && 
                ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_HM"] && 
                ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_YMD"]) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYDateTimeFormat_YMDHM"];
            [[NSUserDefaults standardUserDefaults] setObject:@"yyyy-MM-dd HH:mm" forKey:@"DYYYDateTimeFormat"];
        }
        
        // 更新UI中所有子开关的状态
        [self updateDateTimeFormatSubSwitchesUI:indexPath.section enabled:mainEnabled];
    } 
    // 处理日期时间格式子开关操作
    else if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYShowDateTime"]) {
            // 如果父级开关关闭，则不允许打开子级设置
            sender.on = NO;
            isOn = NO;
            [DYYYManager showToast:@"请先开启「视频-显示日期时间」"];
            return;
        }
        
        // 当任何子开关打开时
        if (isOn) {
            // 确保主开关打开
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYShowDateTime"];
            
            // 关闭其他格式子开关，设置当前格式为默认
            NSString *formatValue = @"";
            if ([item.key isEqualToString:@"DYYYDateTimeFormat_YMDHM"]) {
                formatValue = @"yyyy-MM-dd HH:mm";
                [self updateDateTimeFormatExclusiveSwitch:indexPath.section currentKey:item.key];
            } 
            else if ([item.key isEqualToString:@"DYYYDateTimeFormat_MDHM"]) {
                formatValue = @"MM-dd HH:mm";
                [self updateDateTimeFormatExclusiveSwitch:indexPath.section currentKey:item.key];
            }
            else if ([item.key isEqualToString:@"DYYYDateTimeFormat_HMS"]) {
                formatValue = @"HH:mm:ss";
                [self updateDateTimeFormatExclusiveSwitch:indexPath.section currentKey:item.key];
            }
            else if ([item.key isEqualToString:@"DYYYDateTimeFormat_HM"]) {
                formatValue = @"HH:mm";
                [self updateDateTimeFormatExclusiveSwitch:indexPath.section currentKey:item.key];
            }
            else if ([item.key isEqualToString:@"DYYYDateTimeFormat_YMD"]) {
                formatValue = @"yyyy-MM-dd";
                [self updateDateTimeFormatExclusiveSwitch:indexPath.section currentKey:item.key];
            }
            
            // 更新DateTimeFormat
            if (formatValue.length > 0) {
                [[NSUserDefaults standardUserDefaults] setObject:formatValue forKey:@"DYYYDateTimeFormat"];
            }
            
            // 更新UI中主开关的状态
            [self updateDateTimeFormatMainSwitchUI:indexPath.section];
        } 
        // 当任何子开关关闭时
        else {
            // 将当前子开关设置为关闭
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:item.key];
            
            // 检查是否所有子开关都已关闭
            BOOL anyEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_YMDHM"] || 
                              [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_MDHM"] || 
                              [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_HMS"] || 
                              [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_HM"] || 
                              [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDateTimeFormat_YMD"];
            
            // 如果所有子开关都关闭，也关闭主开关并清除格式
            if (!anyEnabled) {
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYShowDateTime"];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
                for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                    [self updateDateTimeFormatMainSwitchUI:section];
                }
            }
        }
    }
    
    // 保存开关状态 - 使用isOn变量，不是sender.isOn，因为可能已经被上述逻辑修改
    [[NSUserDefaults standardUserDefaults] setBool:isOn forKey:item.key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateAreaMainSwitchUI:(NSInteger)section {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到主开关
        if ([item.key isEqualToString:@"DYYYisEnableArea"]) {
            // 更新UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *mainSwitch = (UISwitch *)cell.accessoryView;
                BOOL shouldBeOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
                mainSwitch.on = shouldBeOn;
            }
            break;
        }
    }
}

- (void)updateAreaSubSwitchesUI:(NSInteger)section enabled:(BOOL)enabled {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到所有子开关
        if ([item.key isEqualToString:@"DYYYisEnableAreaProvince"] || 
            [item.key isEqualToString:@"DYYYisEnableAreaCity"] || 
            [item.key isEqualToString:@"DYYYisEnableAreaDistrict"] || 
            [item.key isEqualToString:@"DYYYisEnableAreaStreet"]) {
            
            // 更新UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = enabled;
            }
        }
    }
}

- (void)updateMutuallyExclusiveSwitches:(NSInteger)section excludingItemKey:(NSString *)excludedKey {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 只处理自定义相册尺寸相关的开关
        if (([item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"] || 
             [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] || 
             [item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"]) && 
            ![item.key isEqualToString:excludedKey]) {
            
            // 查找并更新cell的开关状态
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *cellSwitch = (UISwitch *)cell.accessoryView;
                cellSwitch.on = NO;
            }
        }
    }
}

- (void)updateAllSubswitchesForSection:(NSInteger)section {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 只处理自定义相册尺寸相关的开关
        if ([item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"] || 
            [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] || 
            [item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"]) {
            
            // 查找并更新cell的开关状态
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *cellSwitch = (UISwitch *)cell.accessoryView;
                cellSwitch.on = NO;
            }
        }
    }
}

- (void)updateSubswitchesForSection:(NSInteger)section parentKey:(NSString *)parentKey {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    NSString *prefix = nil;
    if ([parentKey isEqualToString:@"DYYYLongPressDownload"]) {
        prefix = @"DYYYLongPress";
    } else if ([parentKey isEqualToString:@"DYYYCopyText"]) {
        prefix = @"DYYYCopy";
    } else if ([parentKey isEqualToString:@"DYYYEnableDoubleOpenAlertController"]) {
        prefix = @"DYYYDoubleTap";
    }
    
    if (!prefix) return;
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 只处理相关子开关
        if ([item.key hasPrefix:prefix] && ![item.key isEqualToString:parentKey]) {
            // 查找并更新cell的开关状态
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = NO;
            }
        }
    }
}

- (void)updateDateTimeFormatMainSwitchUI:(NSInteger)section {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到主开关
        if ([item.key isEqualToString:@"DYYYShowDateTime"]) {
            // 更新UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *mainSwitch = (UISwitch *)cell.accessoryView;
                BOOL shouldBeOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYShowDateTime"];
                mainSwitch.on = shouldBeOn;
            }
            break;
        }
    }
}

- (void)updateDateTimeFormatSubSwitchesUI:(NSInteger)section enabled:(BOOL)enabled {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到所有子开关
        if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
            // 更新UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = enabled;
            }
        }
    }
}

- (void)updateDateTimeFormatExclusiveSwitch:(NSInteger)section currentKey:(NSString *)currentKey {
    NSArray<NSString *> *allFormatKeys = @[@"DYYYDateTimeFormat_YMDHM", 
                                          @"DYYYDateTimeFormat_MDHM", 
                                          @"DYYYDateTimeFormat_HMS", 
                                          @"DYYYDateTimeFormat_HM", 
                                          @"DYYYDateTimeFormat_YMD"];
    
    // 关闭所有其他格式开关
    for (NSString *key in allFormatKeys) {
        if (![key isEqualToString:currentKey]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:key];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
        }
    }
    
    // 更新UI
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到相关的子开关
        if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = [item.key isEqualToString:currentKey];
            }
        }
    }
}

- (void)textFieldDidChange:(UITextField *)textField {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:textField.tag % 1000 inSection:textField.tag / 1000];
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
        return;
    }
    
    DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
    
    // 添加对链接解析接口的特殊处理
    if ([item.key isEqualToString:@"DYYYInterfaceDownload"]) {
        NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (text.length == 0) {
            textField.text = @"https://api.qsy.ink/api/douyin?url=";
            [[NSUserDefaults standardUserDefaults] setObject:@"https://api.qsy.ink/api/douyin?url=" forKey:item.key];
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:item.key];
        }
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:item.key];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 处理特殊键
    if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
        [self showImagePickerForCustomAlbum];
    }
}

- (void)avatarTextFieldDidChange:(UITextField *)textField {
    self.avatarTapLabel.text = textField.text.length > 0 ? textField.text : @"抖音净化";
}

- (void)headerTapped:(UIButton *)sender {
    // 触发触觉反馈
    [self.feedbackGenerator impactOccurred];
    [self.feedbackGenerator prepare];
    
    NSInteger section = sender.tag;
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section >= sections.count) {
        return;
    }
    
    BOOL isExpanded = [self.expandedSections containsObject:@(section)];
    
    // 关闭其他展开的区段
    NSMutableArray<NSIndexPath *> *rowsToDelete = [NSMutableArray array];
    for (NSNumber *otherSection in self.expandedSections.copy) {
        if (![otherSection isEqualToNumber:@(section)]) {
            [self.expandedSections removeObject:otherSection];
            UIView *otherHeaderView = [self.tableView headerViewForSection:otherSection.integerValue];
            UIImageView *otherArrow = [otherHeaderView viewWithTag:100];
            
            // 添加旋转动画
            [UIView animateWithDuration:0.3 animations:^{
                otherArrow.transform = CGAffineTransformIdentity;
            }];
            
            otherArrow.image = [UIImage systemImageNamed:@"chevron.right"];
            [rowsToDelete addObjectsFromArray:[self rowsForSection:otherSection.integerValue]];
        }
    }
    
    // 更新当前区段状态
    if (isExpanded) {
        [self.expandedSections removeObject:@(section)];
    } else {
        [self.expandedSections addObject:@(section)];
    }
    
    // 更新箭头图标并添加旋转动画
    UIView *headerView = [self.tableView headerViewForSection:section];
    UIImageView *arrow = [headerView viewWithTag:100];
    arrow.image = [UIImage systemImageNamed:isExpanded ? @"chevron.right" : @"chevron.down"];
    
    [UIView animateWithDuration:0.3 animations:^{
        arrow.transform = isExpanded ? CGAffineTransformIdentity : CGAffineTransformMakeRotation(M_PI/2);
    }];
    
    // 获取需要插入或删除的行
    NSArray<NSIndexPath *> *rowsToInsert = isExpanded ? @[] : [self rowsForSection:section];
    NSArray<NSIndexPath *> *rowsToDeleteForCurrent = isExpanded ? [self rowsForSection:section] : @[];
    [rowsToDelete addObjectsFromArray:rowsToDeleteForCurrent];
    
    // 更新表格并增强动画效果
    [self.tableView beginUpdates];
    if (rowsToDelete.count > 0) {
        [self.tableView deleteRowsAtIndexPaths:rowsToDelete withRowAnimation:UITableViewRowAnimationFade];
    }
    if (rowsToInsert.count > 0) {
        [self.tableView insertRowsAtIndexPaths:rowsToInsert withRowAnimation:UITableViewRowAnimationFade];
        
        // 对新插入的行添加延迟显示的动画效果
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (NSIndexPath *indexPath in rowsToInsert) {
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                cell.alpha = 0;
                cell.transform = CGAffineTransformMakeTranslation(20, 0);
                
                [UIView animateWithDuration:0.3 
                                      delay:indexPath.row * 0.05 
                                    options:UIViewAnimationOptionCurveEaseOut 
                                 animations:^{
                    cell.alpha = 1;
                    cell.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
        });
    }
    [self.tableView endUpdates];
}

- (NSArray<NSIndexPath *> *)rowsForSection:(NSInteger)section {
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section >= sections.count) {
        return @[];
    }
    NSInteger rowCount = sections[section].count;
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:rowCount];
    for (NSInteger row = 0; row < rowCount; row++) {
        [rows addObject:[NSIndexPath indexPathForRow:row inSection:section]];
    }
    return rows;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gesture locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (!indexPath) {
            return;
        }
        
        NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
        if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
            return;
        }
        
        DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选项"
                                                                      message:item.title
                                                               preferredStyle:UIAlertControllerStyleActionSheet];
        
        if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
            [alert addAction:[UIAlertAction actionWithTitle:@"从相册选择"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary forCustomAlbum:YES];
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"使用相机"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera forCustomAlbum:YES];
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认图片"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYCustomAlbumImagePath"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [DYYYManager showToast:@"自定义相册图片已设置"];
                [self.tableView reloadData];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
            }]];
        }
        
        // 默认重置选项
        UIAlertAction *resetAction = [UIAlertAction actionWithTitle:@"重置"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:item.key];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // 特殊处理清屏按钮尺寸重置
            if ([item.key isEqualToString:@"DYYYEnableFloatClearButton"] || 
                [item.key isEqualToString:@"DYYYFloatClearButtonSizePreference"]) {
                [[NSUserDefaults standardUserDefaults] setInteger:DYYYButtonSizeMedium 
                                                           forKey:@"DYYYFloatClearButtonSizePreference"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            // 特殊处理日期时间格式相关设置
            if ([item.key isEqualToString:@"DYYYShowDateTime"]) {
                // 重置主开关也重置所有子开关和格式设置
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMDHM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_MDHM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HMS"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMD"];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
                
                // 更新UI中子开关的状态
                for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                    [self updateDateTimeFormatSubSwitchesUI:section enabled:NO];
                }
            }
            else if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
                // 重置一个子开关时检查是否有其他子开关启用
                BOOL anyEnabled = NO;
                for (NSString *key in @[@"DYYYDateTimeFormat_YMDHM", @"DYYYDateTimeFormat_MDHM", 
                                        @"DYYYDateTimeFormat_HMS", @"DYYYDateTimeFormat_HM", 
                                        @"DYYYDateTimeFormat_YMD"]) {
                    if (![key isEqualToString:item.key] && [[NSUserDefaults standardUserDefaults] boolForKey:key]) {
                        anyEnabled = YES;
                        break;
                    }
                }
                
                // 如果所有子开关都关闭，也关闭主开关并清除格式
                if (!anyEnabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYShowDateTime"];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
                    for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                        [self updateDateTimeFormatMainSwitchUI:section];
                    }
                }
            }
            
            // 特殊处理时间属地显示开关组
            if ([item.key isEqualToString:@"DYYYisEnableArea"]) {
                // 重置主开关也重置所有子开关
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaProvince"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaCity"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaDistrict"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaStreet"];
                
                // 更新UI
                for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                    [self updateAreaSubSwitchesUI:section enabled:NO];
                }
            }
            
            // 针对自定义相册图片和大小，重置后刷新按钮
            if ([item.key isEqualToString:@"DYYYCustomAlbumImagePath"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"] ||
                [item.key isEqualToString:@"DYYYEnableCustomAlbum"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
            }
            
            // 处理头像文本
            if ([item.key isEqualToString:@"DYYYAvatarTapText"]) {
                self.avatarTapLabel.text = @"Axs";
            }
            
            // 刷新UI
            [self.tableView reloadData];
            
            // 显示提示
            [DYYYManager showToast:[NSString stringWithFormat:@"已重置: %@", item.title]];
            NSLog(@"DYYY: Reset %@", item.key);
        }];
        [alert addAction:resetAction];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.tableView;
            alert.popoverPresentationController.sourceRect = CGRectMake(point.x, point.y, 1, 1);
        }
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)showImagePickerForCustomAlbum {
    // 检查自定义选择相册图片功能是否启用
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableCustomAlbum"]) {
        [DYYYManager showToast:@"请先开启「自定义选择相册图片」"];
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择图片来源" 
                                                                  message:nil 
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"相册" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary forCustomAlbum:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"相机" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera forCustomAlbum:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYCustomAlbumImagePath"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [DYYYManager showToast:@"已恢复默认相册图片"];
        [self.tableView reloadData];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 
                                                                   self.view.bounds.size.height / 2, 
                                                                   0, 0);
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType forCustomAlbum:(BOOL)isCustomAlbum {
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) {
        [DYYYManager showToast:@"设备不支持该图片来源"];
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = sourceType;
    picker.allowsEditing = YES;
    
    objc_setAssociatedObject(picker, "isCustomAlbumPicker", isCustomAlbum ? @YES : @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)resetButtonTapped:(UIButton *)sender {
    NSString *key = sender.accessibilityLabel;
    if (!key) return;
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 特殊处理清屏按钮尺寸重置
    if ([key isEqualToString:@"DYYYEnableFloatClearButton"] || 
        [key isEqualToString:@"DYYYFloatClearButtonSizePreference"]) {
        [[NSUserDefaults standardUserDefaults] setInteger:DYYYButtonSizeMedium 
                                                   forKey:@"DYYYFloatClearButtonSizePreference"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 特殊处理日期时间格式相关设置
    if ([key isEqualToString:@"DYYYShowDateTime"]) {
        // 重置主开关也重置所有子开关和格式设置
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMDHM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_MDHM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HMS"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMD"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
        
        // 更新UI中子开关的状态
        for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
            [self updateDateTimeFormatSubSwitchesUI:section enabled:NO];
        }
    }
    else if ([key hasPrefix:@"DYYYDateTimeFormat_"]) {
        // 重置一个子开关时检查是否有其他子开关启用
        BOOL anyEnabled = NO;
        for (NSString *formatKey in @[@"DYYYDateTimeFormat_YMDHM", @"DYYYDateTimeFormat_MDHM", 
                                      @"DYYYDateTimeFormat_HMS", @"DYYYDateTimeFormat_HM", 
                                      @"DYYYDateTimeFormat_YMD"]) {
            if (![formatKey isEqualToString:key] && [[NSUserDefaults standardUserDefaults] boolForKey:formatKey]) {
                anyEnabled = YES;
                break;
            }
        }
        
        // 如果所有子开关都关闭，也关闭主开关并清除格式
        if (!anyEnabled) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYShowDateTime"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
            for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                [self updateDateTimeFormatMainSwitchUI:section];
            }
        }
    }
    
    // 特殊处理时间属地显示开关组
    if ([key isEqualToString:@"DYYYisEnableArea"]) {
        // 重置主开关也重置所有子开关
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaProvince"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaCity"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaDistrict"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaStreet"];
        
        // 更新UI
        for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
            [self updateAreaSubSwitchesUI:section enabled:NO];
        }
    }
    
    // 针对自定义相册图片和大小，重置后刷新按钮
    if ([key isEqualToString:@"DYYYCustomAlbumImagePath"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeSmall"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeLarge"] ||
        [key isEqualToString:@"DYYYEnableCustomAlbum"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
    }
    
    // 处理头像文本
    if ([key isEqualToString:@"DYYYAvatarTapText"]) {
        self.avatarTapLabel.text = @"Axs";
    }
    
    // 刷新UI
    [self.tableView reloadData];
    
    // 显示提示
    [DYYYManager showToast:[NSString stringWithFormat:@"已重置: %@", key]];
}

- (void)showSourceCodePopup {
    NSString *githubURL = @"https://github.com/huami1314/dyyy";
    
    // 添加跳转前的动画效果
    CAKeyframeAnimation *pulseAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.values = @[@1.0, @1.08, @1.0];
    pulseAnimation.keyTimes = @[@0, @0.5, @1.0];
    pulseAnimation.duration = 0.5;
    pulseAnimation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                      [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    
    UIButton *sourceButton = (UIButton *)[self.tableView.tableFooterView viewWithTag:101];
    [sourceButton.layer addAnimation:pulseAnimation forKey:@"pulse"];
    
    // 添加0.5秒延迟，让动画效果完成后再跳转
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:githubURL] options:@{} completionHandler:nil];
    });
}

#pragma mark - Notification Handling

- (void)handleBackgroundColorChanged {
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    UIColor *color = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor whiteColor];
    self.backgroundColorView.backgroundColor = color;
}

#pragma mark - Dealloc

- (void)dealloc {
    if (self.isKVOAdded && self.tableView) {
        @try {
            [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
            self.isKVOAdded = NO;
        } @catch (NSException *exception) {
        }
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYBackgroundColorChanged" object:nil];
}

@end
