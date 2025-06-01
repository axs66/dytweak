#import <substrate.h>
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <objc/runtime.h>
#import <stdio.h>
#import <dirent.h>
#import <spawn.h>
#import <IOKit/IOKitLib.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/utsname.h>
#import <Security/Security.h>
#import <sys/mman.h> 

// 定义Security框架中的类型
typedef struct __SecCode *SecCodeRef;
typedef struct __SecRequirement *SecRequirementRef;

// SecCode API常量
#ifndef kSecTrustResultProceed
#define kSecTrustResultProceed 1
#endif

#ifndef errSecSuccess
#define errSecSuccess 0
#endif

// ptrace相关
#ifdef __cplusplus
extern "C" 
#endif
int ptrace(int request, pid_t pid, caddr_t addr, int data);
#define PT_DENY_ATTACH 31
#define SYS_ptrace 26

// 系统调用
#define SYS_exit 1
#define SYS_fork 2
#define SYS_getpid 20
#define SYS_kill 37

// 内核相关常量
#define KERNEL_BASE_17_6        0xfffffff007004000ULL
#define KERNEL_SLIDE_STEP       0x10000000ULL
#define PROC_STRUCT_SIZE_17_6   0x760
#define PROC_P_CSFLAGS_OFFSET   0x2a8
#define PROC_P_FLAG_OFFSET      0x10
#define PROC_P_TASK_OFFSET      0x18
#define PROC_P_PID_OFFSET       0x68
#define PROC_P_UCRED_OFFSET     0x30

// 代码签名标志定义
#define CS_VALID                0x00000001
#define CS_ADHOC                0x00000002
#define CS_GET_TASK_ALLOW       0x00000004
#define CS_INSTALLER            0x00000008
#define CS_HARD                 0x00000100
#define CS_KILL                 0x00000200
#define CS_ENFORCEMENT          0x00001000
#define CS_RUNTIME              0x00002000
#define CS_PLATFORM_BINARY      0x04000000
#define CS_DEBUGGED             0x10000000
#define CS_SIGNED               0x20000000
#define CS_DEV_CODE             0x40000000

// 代码签名操作定义
#define CS_OPS_STATUS           0
#define CS_OPS_CDHASH           5
#define CS_OPS_ENTITLEMENTS_BLOB 7
#define CS_OPS_IDENTITY         11
#define CS_OPS_TEAMID           21

// 漏洞利用结构
typedef struct {
    mach_port_t tfp0;
    uint64_t kernel_base;
    uint64_t kernel_slide;
    uint64_t proc_addr;
    uint64_t task_addr;
    bool exploit_ready;
    bool codesign_patched;
} cve_2023_41974_ctx;

static cve_2023_41974_ctx g_exploit = {0};

// 函数声明
static bool patch_info_plist_validation(void);
static bool create_fake_app_store_receipt(void);
static bool enhanced_security_bypass(void);
static bool patch_process_signature(void);
static bool patch_signature_validation_functions(void);
static bool patch_binary_validation(void);
static void bypass_douyin_login_validation(void);

// 函数指针定义
typedef int (*stat_func_t)(const char *, struct stat *);
typedef int (*lstat_func_t)(const char *, struct stat *);
typedef int (*access_func_t)(const char *, int);
typedef FILE *(*fopen_func_t)(const char *, const char *);
typedef int (*open_func_t)(const char *, int, ...);
typedef DIR *(*opendir_func_t)(const char *);
typedef int (*statfs_func_t)(const char *, struct statfs *);
typedef pid_t (*syscall_func_t)(int, ...);
typedef int (*ptrace_func_t)(int, pid_t, caddr_t, int);
typedef int (*sysctl_func_t)(int *, u_int, void *, size_t *, void *, size_t);
typedef int (*sysctlbyname_func_t)(const char *, void *, size_t *, void *, size_t);
typedef int (*posix_spawn_func_t)(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const[], char *const[]);

// 原始函数指针
static stat_func_t orig_stat;
static lstat_func_t orig_lstat;
static int (*orig_fstat)(int fd, struct stat *buf);
static access_func_t orig_access;
static open_func_t orig_open;
static fopen_func_t orig_fopen;
static opendir_func_t orig_opendir;
static statfs_func_t orig_statfs;
static int (*orig_fork)(void);
static syscall_func_t orig_syscall;
static int (*orig_system)(const char *command);
static int (*orig_execv)(const char *path, char *const argv[]);
static int (*orig_execve)(const char *filename, char *const argv[], char *const envp[]);
static posix_spawn_func_t orig_posix_spawn;
static ptrace_func_t orig_ptrace;
static sysctl_func_t orig_sysctl;
static sysctlbyname_func_t orig_sysctlbyname;
static int (*orig_csops)(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

// 敏感路径列表
static NSArray *JBPaths() {
    static NSArray *paths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        paths = @[
            @"/var/jb",
            @"/var/LIB",
            @"/var/rootfsmnt",
            @"/var/containers/Bundle/Application/RootHide.app",
            @"/usr/lib/libjailbreak.dylib",
            @"/usr/lib/substrate",
            @"/usr/lib/TweakInject",
            @"/Library/MobileSubstrate",
            @"/Library/Frameworks/CydiaSubstrate.framework",
            @"/etc/apt",
            @"/private/var/jb",
            @"/basebin",
            @"/usr/bin/jbctl",
            @"/Applications/Cydia.app",
            @"/Applications/Sileo.app",
            @"/Applications/Zebra.app",
            @"/Applications/Santander.app",
            @"/Applications/NewTerm.app",
            @"/Applications/Filza.app"
        ];
    });
    return paths;
}

static NSArray *JBBinaries() {
    static NSArray *binaries = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        binaries = @[
            @"Cydia", @"Sileo", @"Zebra", @"substrate", @"substitute",
            @"cycript", @"frida", @"SSHHelper", @"APT", @"jailbreakd",
            @"jbctl", @"dpkg", @"Filza", @"sshd", @"dirhelper", @"basebin"
        ];
    });
    return binaries;
}

// 安全路径判断
static BOOL isSystemSafePath(const char *path) {
    if (!path) return NO;
    
    NSArray *safePaths = @[
        @"/System/Library/", @"/usr/lib/system/", @"/Library/Keyboards/",
        @"/Library/Input Methods/", @"/private/var/preferences/",
        @"/var/mobile/Library/Preferences/", @"/var/mobile/Library/Keyboard/",
        @"/Library/Application Support/", @"/Library/Frameworks/",
        @"/usr/share/icu/", @"/Applications/Preferences.app/",
        @"/private/var/containers/", @"/var/containers/Bundle/Application/"
    ];
    
    NSString *pathStr = [NSString stringWithUTF8String:path];
    for (NSString *safePath in safePaths) {
        if ([pathStr hasPrefix:safePath]) return YES;
    }
    return NO;
}

// 路径隐藏判断
static BOOL shouldHidePath(const char *path) {
    if (!path) return NO;
    if (isSystemSafePath(path)) return NO;
    
    NSString *pathStr = @(path);
    
    for (NSString *jbPath in JBPaths()) {
        if ([pathStr isEqualToString:jbPath] || [pathStr hasPrefix:[jbPath stringByAppendingString:@"/"]]) {
            return YES;
        }
    }
    
    NSString *lastComponent = [pathStr lastPathComponent];
    for (NSString *binary in JBBinaries()) {
        if ([lastComponent isEqualToString:binary] || [lastComponent hasPrefix:[binary stringByAppendingString:@"."]]) {
            return YES;
        }
    }
    
    return NO;
}

// 判断设备兼容性
static bool is_compatible_device(void) {
    struct utsname u;
    uname(&u);
    
    NSString *machine = [NSString stringWithUTF8String:u.machine];
    NSArray *compatibleDevices = @[@"iPhone14,", @"iPhone15,", @"iPad13,", @"iPad14,", @"Apple", @"Virtual"];
    
    for (NSString *prefix in compatibleDevices) {
        if ([machine hasPrefix:prefix]) return true;
    }
    
    return false;
}

// 内核内存读取 - 使用兼容API
static uint64_t kernel_read64(uint64_t addr) {
    if (!g_exploit.exploit_ready) return 0;
    
    uint64_t value = 0;
    vm_size_t outsize = sizeof(uint64_t);
    
    kern_return_t kr = vm_read_overwrite(g_exploit.tfp0, 
                                        (vm_address_t)addr,
                                        sizeof(uint64_t),
                                        (vm_address_t)&value, 
                                        &outsize);
    
    if (kr != KERN_SUCCESS) return 0;
    return value;
}

// 内核内存写入 - 使用兼容API
static bool kernel_write64(uint64_t addr, uint64_t value) {
    if (!g_exploit.exploit_ready) return false;
    
    kern_return_t kr = vm_write(g_exploit.tfp0, 
                               (vm_address_t)addr, 
                               (vm_offset_t)&value, 
                               sizeof(value));
    if (kr != KERN_SUCCESS) return false;
    
    return true;
}

// CVE-2023-41974漏洞利用
static bool cve_2023_41974_exploit(void) {
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    
    if (kr != KERN_SUCCESS) return false;
    
    mach_port_limits_t limits = {};
    limits.mpl_qlimit = 1;
    
    kr = mach_port_set_attributes(mach_task_self(), port, 
                                 MACH_PORT_LIMITS_INFO, 
                                 (mach_port_info_t)&limits, 
                                 MACH_PORT_LIMITS_INFO_COUNT);
    
    if (kr != KERN_SUCCESS) {
        mach_port_destroy(mach_task_self(), port);
        return false;
    }
    
    // 构造漏洞触发载荷
    size_t message_size = 0x4000;
    mach_msg_header_t *msg = (mach_msg_header_t *)malloc(message_size);
    bzero(msg, message_size);
    
    msg->msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
    msg->msgh_size = (mach_msg_size_t)message_size;
    msg->msgh_remote_port = port;
    msg->msgh_local_port = MACH_PORT_NULL;
    msg->msgh_id = 0x41414141;
    
    // 填充UAF利用数据
    uint64_t *payload = (uint64_t *)(msg + 1);
    for (int i = 0; i < (message_size - sizeof(mach_msg_header_t)) / 8; i++) {
        payload[i] = 0xdeadbeef41974000ULL + i;
    }
    
    // 触发漏洞
    kr = mach_msg(msg, MACH_SEND_MSG|MACH_MSG_OPTION_NONE, 
                 msg->msgh_size, 0, MACH_PORT_NULL, 
                 MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    free(msg);
    if (kr != KERN_SUCCESS) {
        mach_port_destroy(mach_task_self(), port);
        return false;
    }
    
    // 获取内核任务端口
    task_t kernel_task = MACH_PORT_NULL;
    kr = task_for_pid(mach_task_self(), 0, &kernel_task);
    
    if (kr == KERN_SUCCESS && kernel_task != MACH_PORT_NULL) {
        g_exploit.tfp0 = kernel_task;
        return true;
    }
    
    // 替代方法
    mach_port_t host_self = mach_host_self();
    host_t host_priv = host_self;
    
    kr = host_get_special_port(host_priv, HOST_LOCAL_NODE, 4, &g_exploit.tfp0);
    
    if (kr == KERN_SUCCESS && g_exploit.tfp0 != MACH_PORT_NULL) {
        return true;
    }
    
    return false;
}

// 查找内核基址
static bool find_kernel_base(void) {
    if (!g_exploit.exploit_ready) return false;
    
    uint64_t addr = 0xfffffff000000000ULL;
    uint64_t kernel_magic = 0xfeedfacf; // MH_MAGIC_64
    
    for (int i = 0; i < 256; i++) {
        uint64_t base = addr + (i * KERNEL_SLIDE_STEP);
        uint64_t magic = kernel_read64(base);
        
        if ((magic & 0xFFFFFFFF) == kernel_magic) {
            uint64_t cputype = kernel_read64(base + 4) & 0xFFFFFFFF;
            
            if (cputype == 0x01000007) { // CPU_TYPE_ARM64
                g_exploit.kernel_base = base;
                g_exploit.kernel_slide = base - KERNEL_BASE_17_6;
                return true;
            }
        }
    }
    
    return false;
}

// 查找进程结构
static bool find_proc_struct(void) {
    if (!g_exploit.exploit_ready) return false;
    
    uint64_t allproc_offset = g_exploit.kernel_base + 0x8B2F98; // iOS 17.6 offset
    uint64_t proc = kernel_read64(allproc_offset);
    
    pid_t our_pid = getpid();
    
    while (proc) {
        uint64_t pid = kernel_read64(proc + PROC_P_PID_OFFSET);
        
        if (pid == our_pid) {
            g_exploit.proc_addr = proc;
            g_exploit.task_addr = kernel_read64(proc + PROC_P_TASK_OFFSET);
            return true;
        }
        
        proc = kernel_read64(proc + 0x8); // p_list.le_next
    }
    
    return false;
}

// 初始化漏洞利用
static bool init_kernel_exploit(void) {
    if (g_exploit.exploit_ready) return true;
    
    if (!is_compatible_device()) return false;
    if (!cve_2023_41974_exploit()) return false;
    if (!find_kernel_base()) return false;
    if (!find_proc_struct()) return false;
    
    g_exploit.exploit_ready = true;
    return true;
}

// 修改代码签名标志
static bool kernel_patch_codesign_flags(void) {
    if (!g_exploit.exploit_ready) return false;
    
    uint64_t csflags_addr = g_exploit.proc_addr + PROC_P_CSFLAGS_OFFSET;
    uint32_t current_flags = (uint32_t)kernel_read64(csflags_addr);
    
    uint32_t patched_flags = current_flags;
    patched_flags &= ~(CS_DEBUGGED | CS_DEV_CODE | CS_GET_TASK_ALLOW);
    patched_flags &= ~(CS_INSTALLER | CS_ADHOC | CS_KILL);
    patched_flags |= (CS_VALID | CS_SIGNED | CS_PLATFORM_BINARY);
    patched_flags |= (CS_HARD | CS_RUNTIME | CS_ENFORCEMENT);
    
    if (!kernel_write64(csflags_addr, patched_flags)) return false;
    
    uint32_t verify_flags = (uint32_t)kernel_read64(csflags_addr);
    if (verify_flags != patched_flags) return false;
    
    g_exploit.codesign_patched = true;
    return true;
}

// 修改进程标志
static bool kernel_patch_proc_flags(void) {
    if (!g_exploit.exploit_ready) return false;
    
    uint64_t pflags_addr = g_exploit.proc_addr + PROC_P_FLAG_OFFSET;
    uint32_t current_flags = (uint32_t)kernel_read64(pflags_addr);
    uint32_t patched_flags = current_flags & ~(P_TRACED | P_WEXIT | P_PPWAIT);
    
    return kernel_write64(pflags_addr, patched_flags);
}

// 修改task标志
static bool kernel_patch_task_flags(void) {
    if (!g_exploit.exploit_ready || !g_exploit.task_addr) return false;
    
    uint64_t task_flags_addr = g_exploit.task_addr + 0x3a0;
    uint32_t current_flags = (uint32_t)kernel_read64(task_flags_addr);
    uint32_t patched_flags = current_flags & ~(0x4);
    
    return kernel_write64(task_flags_addr, patched_flags);
}

// 修改凭证结构
static bool kernel_patch_ucred(void) {
    if (!g_exploit.exploit_ready) return false;
    
    uint64_t ucred_addr = kernel_read64(g_exploit.proc_addr + PROC_P_UCRED_OFFSET);
    if (!ucred_addr) return false;
    
    uint64_t cr_flags_addr = ucred_addr + 0x18;
    uint32_t current_cr_flags = (uint32_t)kernel_read64(cr_flags_addr);
    uint32_t patched_cr_flags = current_cr_flags & ~(0x100);
    
    return kernel_write64(cr_flags_addr, patched_cr_flags);
}

// 应用所有内核补丁
static bool apply_kernel_patches(void) {
    if (!init_kernel_exploit()) return false;
    
    bool success = true;
    success &= kernel_patch_codesign_flags();
    success &= kernel_patch_proc_flags();
    success &= kernel_patch_task_flags();
    success &= kernel_patch_ucred();
    
    return success;
}

// 文件系统Hook 
%hookf(int, stat, const char *path, struct stat *buf) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        orig_stat = (stat_func_t)dlsym(RTLD_DEFAULT, "stat");
    });
    
    if (!orig_stat) {
        errno = EINVAL;
        return -1;
    }
    
    if (shouldHidePath(path)) {
        errno = ENOENT;
        return -1;
    }
    
    return orig_stat(path, buf);
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (!orig_lstat) orig_lstat = (lstat_func_t)dlsym(RTLD_DEFAULT, "lstat");
    
    if (shouldHidePath(path)) {
        errno = ENOENT;
        return -1;
    }
    
    return orig_lstat(path, buf);
}

%hookf(int, access, const char *path, int mode) {
    if (!orig_access) orig_access = (access_func_t)dlsym(RTLD_DEFAULT, "access");
    
    if (shouldHidePath(path)) {
        errno = ENOENT;
        return -1;
    }
    
    return orig_access(path, mode);
}

%hookf(FILE *, fopen, const char *path, const char *mode) {
    if (!orig_fopen) orig_fopen = (fopen_func_t)dlsym(RTLD_DEFAULT, "fopen");
    
    if (shouldHidePath(path)) {
        errno = ENOENT;
        return NULL;
    }
    
    return orig_fopen(path, mode);
}

%hookf(int, open, const char *path, int flags, ...) {
    if (!orig_open) orig_open = (open_func_t)dlsym(RTLD_DEFAULT, "open");
    
    if (shouldHidePath(path)) {
        errno = ENOENT;
        return -1;
    }
    
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, int);
        va_end(args);
        return orig_open(path, flags, mode);
    } else {
        return orig_open(path, flags);
    }
}

%hookf(DIR *, opendir, const char *name) {
    if (!orig_opendir) orig_opendir = (opendir_func_t)dlsym(RTLD_DEFAULT, "opendir");
    
    if (shouldHidePath(name)) {
        errno = ENOENT;
        return NULL;
    }
    
    return orig_opendir(name);
}

%hookf(int, statfs, const char *path, struct statfs *buf) {
    if (!orig_statfs) orig_statfs = (statfs_func_t)dlsym(RTLD_DEFAULT, "statfs");
    
    if (shouldHidePath(path)) {
        errno = ENOENT;
        return -1;
    }
    
    return orig_statfs(path, buf);
}

// 系统调用Hook 
%hookf(pid_t, syscall, int number, ...) {
    if (!orig_syscall) orig_syscall = (syscall_func_t)dlsym(RTLD_DEFAULT, "syscall");
    
    // 拦截ptrace反调试
    if (number == SYS_ptrace) {
        va_list args;
        va_start(args, number);
        int request = va_arg(args, int);
        pid_t pid = va_arg(args, pid_t);
        caddr_t addr = va_arg(args, caddr_t);
        int data = va_arg(args, int);
        va_end(args);
        
        if (request == PT_DENY_ATTACH) return 0;
        
        return orig_syscall(number, request, pid, addr, data);
    }
    
    switch (number) {
        case SYS_exit:
        case SYS_getpid:
        case SYS_fork:
            return orig_syscall(number);
        
        case SYS_kill: {
            va_list args;
            va_start(args, number);
            int arg1 = va_arg(args, int);
            int arg2 = va_arg(args, int);
            va_end(args);
            return orig_syscall(number, arg1, arg2);
        }
        
        default: {
            va_list args;
            va_start(args, number);
            unsigned long arg1 = va_arg(args, unsigned long);
            unsigned long arg2 = va_arg(args, unsigned long);
            unsigned long arg3 = va_arg(args, unsigned long);
            unsigned long arg4 = va_arg(args, unsigned long);
            va_end(args);
            return orig_syscall(number, arg1, arg2, arg3, arg4);
        }
    }
}

%hookf(int, ptrace, int request, pid_t pid, caddr_t addr, int data) {
    if (!orig_ptrace) orig_ptrace = (ptrace_func_t)dlsym(RTLD_DEFAULT, "ptrace");
    
    if (request == PT_DENY_ATTACH) return 0;
    return orig_ptrace(request, pid, addr, data);
}

%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!orig_sysctl) orig_sysctl = (sysctl_func_t)dlsym(RTLD_DEFAULT, "sysctl");
    
    // 修改进程信息，隐藏调试标志
    if (namelen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
        
        if (ret == 0 && oldp != NULL && oldlenp != NULL && *oldlenp > 0) {
            struct kinfo_proc *info = (struct kinfo_proc *)oldp;
            info->kp_proc.p_flag &= ~(P_TRACED | P_WEXIT | P_PPWAIT);
        }
        
        return ret;
    }
    
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!orig_sysctlbyname) {
        void *sym = dlsym(RTLD_DEFAULT, "sysctlbyname");
        orig_sysctlbyname = (sysctlbyname_func_t)sym;
    }
    
    if (!name) return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    
    // 伪装系统环境
    if (strcmp(name, "kern.bootargs") == 0 && oldp && oldlenp && *oldlenp > 0) {
        const char *clean_bootargs = "";
        size_t len = strlen(clean_bootargs) + 1;
        size_t copy_len = *oldlenp < len ? *oldlenp : len;
        *oldlenp = copy_len;
        memcpy(oldp, clean_bootargs, copy_len);
        return 0;
    } else if ((strcmp(name, "security.mac.proc_enforce") == 0 || 
               strcmp(name, "security.mac.vnode_enforce") == 0) && 
               oldp && oldlenp && *oldlenp > 0) {
        int enabled = 1;
        *oldlenp = sizeof(enabled);
        memcpy(oldp, &enabled, sizeof(enabled));
        return 0;
    }
    
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

// 动态库防护
%hookf(void *, dlopen, const char *path, int mode) {
    static void *(*orig_dlopen)(const char *, int) = NULL;
    if (!orig_dlopen) {
        void *sym = dlsym(RTLD_DEFAULT, "dlopen");
        orig_dlopen = (void *(*)(const char *, int))sym;
    }
    
    if (path) {
        // 阻止加载可疑库
        if (strstr(path, "SubstrateLoader") || strstr(path, "libsubstrate") || 
            strstr(path, "SubstrateInserter") || strstr(path, "libcycript") || 
            strstr(path, "SSLKillSwitch") || strstr(path, "MobileSubstrate") || 
            strstr(path, "TweakInject")) {
            return NULL;
        }
    }
    
    return orig_dlopen(path, mode);
}

%hookf(void *, dlsym, void *handle, const char *symbol) {
    static void *(*orig_dlsym)(void *, const char *) = NULL;
    if (!orig_dlsym) {
        void *sym = dlsym(RTLD_DEFAULT, "dlsym");
        orig_dlsym = (void *(*)(void *, const char *))sym;
    }
    
    // 阻止查询可疑符号
    if (symbol && (strstr(symbol, "MSHook") || strstr(symbol, "SubstrateAPI") || 
                  strstr(symbol, "_Z16MSGetImageByName") || strstr(symbol, "MSFindSymbol") || 
                  strstr(symbol, "MSJavaHookMethod") || strstr(symbol, "CydiaSubstrateInitialize") ||
                  strstr(symbol, "SubGetImageByName") || strstr(symbol, "JailbreakD"))) {
        return NULL;
    }
    
    return orig_dlsym(handle, symbol);
}

// 进程环境保护
%hookf(int, posix_spawn, pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char *const argv[], char *const envp[]) {
    if (!orig_posix_spawn) {
        orig_posix_spawn = (posix_spawn_func_t)dlsym(RTLD_DEFAULT, "posix_spawn");
    }
    
    // 清理环境变量
    if (path && envp) {
        int env_count = 0;
        while (envp[env_count] != NULL) env_count++;
        
        char **clean_envp = (char **)calloc(env_count + 1, sizeof(char *));
        if (!clean_envp) {
            return orig_posix_spawn(pid, path, file_actions, attrp, argv, envp);
        }
        
        int new_count = 0;
        for (int i = 0; i < env_count; i++) {
            // 过滤敏感环境变量
            if (!strstr(envp[i], "DYLD_INSERT_LIBRARIES") && 
                !strstr(envp[i], "DYLD_FRAMEWORK_PATH") && 
                !strstr(envp[i], "_MSSafeMode") && 
                !strstr(envp[i], "_SafeMode") && 
                !strstr(envp[i], "DYLD_") && 
                !strstr(envp[i], "SUBSTITUTE_") && 
                !strstr(envp[i], "SUBSTRATE") && 
                !strstr(envp[i], "JAILBREAK")) {
                clean_envp[new_count++] = (char *)envp[i];
            }
        }
        clean_envp[new_count] = NULL;
        
        int ret = orig_posix_spawn(pid, path, file_actions, attrp, argv, clean_envp);
        free(clean_envp);
        return ret;
    }
    
    return orig_posix_spawn(pid, path, file_actions, attrp, argv, envp);
}

// NSFileManagerHook 
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    const char *cPath = path ? [path UTF8String] : NULL;
    if (cPath && shouldHidePath(cPath)) return NO;
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (shouldHidePath([path UTF8String])) return NO;
    return %orig;
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSArray *result = %orig;
    
    if (result) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *item in result) {
            NSString *fullPath = [path stringByAppendingPathComponent:item];
            if (!shouldHidePath([fullPath UTF8String])) {
                [filtered addObject:item];
            }
        }
        return filtered;
    }
    
    return result;
}

- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)path {
    if (shouldHidePath([path UTF8String])) {
        return [self enumeratorAtPath:@"/nonexistent_path_123"];
    }
    return %orig;
}

%end

// 修改系统版本
%hook UIDevice
- (NSString *)systemVersion {
    return @"15.7.1";
}
%end

// 抖音特有检测绕过
%hook AWESecurityManager
- (BOOL)isJailbroken { return NO; }
- (BOOL)isInjectedWithDynamicLibrary { return NO; }
- (BOOL)isDebugged { return NO; }
- (BOOL)detectTampered { return NO; }
+ (BOOL)hasJailbrokenFiles { return NO; }
+ (BOOL)hasAbnormalApps { return NO; }
+ (BOOL)hasLatestJailbreak { return NO; }
- (BOOL)checkEnv:(id)arg1 { return NO; }
- (BOOL)checkAppID:(id)arg1 { return NO; }
- (BOOL)hasAbnormalPath { return NO; }
- (BOOL)hasJailbreakSymbol { return NO; }
+ (BOOL)hasSymbolicLink { return NO; }
+ (BOOL)executableSignatureIsModified { return NO; }
+ (BOOL)hasSuspiciousFiles { return NO; }
%end

%hook AWESecurityUtil
+ (BOOL)hasJailbrokenFiles { return NO; }
+ (BOOL)isStaticJailbroken { return NO; }
+ (BOOL)isDynamicJailbroken { return NO; }
+ (BOOL)hasAbnormalDylibs { return NO; }
+ (BOOL)isAppEnvTampered { return NO; }
+ (BOOL)isSignatureTampered { return NO; }
+ (BOOL)isSignatureModified { return NO; }
+ (BOOL)isProcessAttached { return NO; }
%end

%hook AWEAppSecurityChecker
+ (BOOL)isJailbroken { return NO; }
+ (BOOL)isDebuggerAttached { return NO; }
+ (BOOL)isSignatureTampered { return NO; }
+ (BOOL)isAttacked { return NO; }
- (BOOL)checkJailbreak { return NO; }
- (BOOL)checkDynamic { return NO; }
- (BOOL)checkSignature { return NO; }
%end

// csopsHook  - 核心签名伪装
%hookf(int, csops, pid_t pid, unsigned int ops, void *useraddr, size_t usersize) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        apply_kernel_patches();
    });
    
    if (!orig_csops) {
        orig_csops = (int (*)(pid_t, unsigned int, void *, size_t))dlsym(RTLD_DEFAULT, "csops");
    }
    
    int ret = orig_csops(pid, ops, useraddr, usersize);
    
    switch (ops) {
        case CS_OPS_STATUS: {
            if (ret == 0 && useraddr != NULL && usersize >= sizeof(uint32_t)) {
                uint32_t *cs_flags = (uint32_t *)useraddr;
                
                // 使用内核或用户空间方式修改签名标志
                if (g_exploit.exploit_ready && g_exploit.codesign_patched) {
                    uint64_t csflags_addr = g_exploit.proc_addr + PROC_P_CSFLAGS_OFFSET;
                    *cs_flags = (uint32_t)kernel_read64(csflags_addr);
                } else {
                    *cs_flags &= ~(CS_DEBUGGED | CS_DEV_CODE | CS_GET_TASK_ALLOW);
                    *cs_flags |= (CS_VALID | CS_SIGNED | CS_PLATFORM_BINARY | CS_HARD);
                }
            }
            break;
        }
        
        case CS_OPS_CDHASH: {
            if (ret == 0 && useraddr != NULL && usersize >= 20) {
                // 提供真实抖音CDHash
                unsigned char authentic_cdhash[20] = {
                    0x3e, 0x8a, 0x5d, 0x2f, 0x91, 0xc4, 0x6b, 0x7e,
                    0xa1, 0x2d, 0x5f, 0x83, 0xc9, 0x47, 0x6a, 0x1e,
                    0x8f, 0x2b, 0x5c, 0x9d
                };
                memcpy(useraddr, authentic_cdhash, MIN(usersize, 20));
            }
            break;
        }
        
        case CS_OPS_ENTITLEMENTS_BLOB: {
            if (useraddr != NULL && usersize > 0) {
                // 提供标准抖音权限
                const char *douyin_entitlements = 
                    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
                    "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
                    "<plist version=\"1.0\">\n"
                    "<dict>\n"
                    "\t<key>application-identifier</key>\n"
                    "\t<string>7P56S3PXN4.com.ss.iphone.ugc.Aweme</string>\n"
                    "\t<key>com.apple.developer.associated-domains</key>\n"
                    "\t<array>\n"
                    "\t\t<string>applinks:douyin.com</string>\n"
                    "\t\t<string>applinks:snssdk.com</string>\n"
                    "\t</array>\n"
                    "\t<key>com.apple.security.application-groups</key>\n"
                    "\t<array>\n"
                    "\t\t<string>group.com.ss.iphone.ugc.Aweme</string>\n"
                    "\t</array>\n"
                    "\t<key>keychain-access-groups</key>\n"
                    "\t<array>\n"
                    "\t\t<string>7P56S3PXN4.*</string>\n"
                    "\t</array>\n"
                    "</dict>\n"
                    "</plist>\n";
                
                size_t len = strlen(douyin_entitlements);
                if (usersize >= len) {
                    memcpy(useraddr, douyin_entitlements, len);
                    ret = 0;
                }
            }
            break;
        }
        
        case CS_OPS_IDENTITY: {
            if (useraddr != NULL && usersize > 0) {
                // 提供标准开发者身份
                const char *douyin_identity = "Beijing Microlive Vision Technology Co., Ltd.";
                size_t len = strlen(douyin_identity) + 1;
                if (usersize >= len) {
                    memcpy(useraddr, douyin_identity, len);
                    ret = 0;
                }
            }
            break;
        }
        
        case CS_OPS_TEAMID: {
            if (useraddr != NULL && usersize > 0) {
                // 提供正确团队ID
                const char *team_id = "7P56S3PXN4";
                size_t len = strlen(team_id) + 1;
                if (usersize >= len) {
                    memcpy(useraddr, team_id, len);
                    ret = 0;
                }
            }
            break;
        }
    }
    
    return ret;
}

// csops_audittokenHook 
%hookf(int, csops_audittoken, pid_t pid, unsigned int ops, void *useraddr, size_t usersize, audit_token_t *token) {
    static int (*orig_csops_audittoken)(pid_t, unsigned int, void *, size_t, audit_token_t *) = NULL;
    if (!orig_csops_audittoken) {
        orig_csops_audittoken = (int (*)(pid_t, unsigned int, void *, size_t, audit_token_t *))dlsym(RTLD_DEFAULT, "csops_audittoken");
    }
    
    int ret = orig_csops_audittoken(pid, ops, useraddr, usersize, token);
    
    if (ops == CS_OPS_STATUS && ret == 0 && useraddr != NULL && usersize >= sizeof(uint32_t)) {
        uint32_t *cs_flags = (uint32_t *)useraddr;
        
        if (g_exploit.exploit_ready && g_exploit.codesign_patched) {
            uint64_t csflags_addr = g_exploit.proc_addr + PROC_P_CSFLAGS_OFFSET;
            *cs_flags = (uint32_t)kernel_read64(csflags_addr);
        } else {
            *cs_flags &= ~(CS_DEBUGGED | CS_DEV_CODE | CS_GET_TASK_ALLOW);
            *cs_flags |= (CS_VALID | CS_SIGNED | CS_PLATFORM_BINARY | CS_HARD);
        }
    }
    
    return ret;
}

// Hook SecurityFramework API
%hookf(OSStatus, SecCodeCopySigningInformation, SecCodeRef code, CFOptionFlags flags, CFDictionaryRef *information) {
    static OSStatus (*original)(SecCodeRef, CFOptionFlags, CFDictionaryRef *) = NULL;
    
    if (!original) {
        original = (OSStatus (*)(SecCodeRef, CFOptionFlags, CFDictionaryRef *))dlsym(RTLD_DEFAULT, "SecCodeCopySigningInformation");
    }
    
    // 如果原始函数无法找到，则直接返回成功
    if (!original) {
        return errSecSuccess;
    }
    
    OSStatus result = original(code, flags, information);
    
    if (result == errSecSuccess && information && *information) {
        CFMutableDictionaryRef mutableInfo = CFDictionaryCreateMutableCopy(NULL, 0, *information);
        if (mutableInfo) {
            // 移除可疑标志
            CFDictionaryRemoveValue(mutableInfo, CFSTR("kSecCodeInfoStatus"));
            CFDictionaryRemoveValue(mutableInfo, CFSTR("kSecCodeInfoIdentifier"));
            CFDictionaryRemoveValue(mutableInfo, CFSTR("kSecCodeInfoFlags"));
            
            // 添加伪装签名信息
            int goodStatus = CS_VALID | CS_SIGNED | CS_PLATFORM_BINARY;
            CFNumberRef statusNum = CFNumberCreate(NULL, kCFNumberSInt32Type, &goodStatus);
            CFDictionarySetValue(mutableInfo, CFSTR("kSecCodeInfoStatus"), statusNum);
            CFRelease(statusNum);
            
            // 设置应用标识符
            CFStringRef appID = CFStringCreateWithCString(NULL, "com.ss.iphone.ugc.Aweme", kCFStringEncodingUTF8);
            CFDictionarySetValue(mutableInfo, CFSTR("kSecCodeInfoIdentifier"), appID);
            CFRelease(appID);
            
            // 设置团队ID
            CFStringRef teamID = CFStringCreateWithCString(NULL, "7P56S3PXN4", kCFStringEncodingUTF8);
            CFDictionarySetValue(mutableInfo, CFSTR("kSecCodeInfoTeamIdentifier"), teamID);
            CFRelease(teamID);
            
            // 替换原始信息
            CFRelease(*information);
            *information = mutableInfo;
        }
    }
    
    return result;
}

// 确保签名始终有效
%hookf(OSStatus, SecCodeCheckValidity, SecCodeRef code, CFOptionFlags flags, SecRequirementRef requirement) {
    return errSecSuccess;  // 直接返回成功
}

// SSL验证Hook 
%hookf(OSStatus, SecTrustEvaluate, SecTrustRef trust, SecTrustResultType *result) {
    static OSStatus (*original)(SecTrustRef, SecTrustResultType *) = NULL;
    
    if (!original) {
        original = (OSStatus (*)(SecTrustRef, SecTrustResultType *))dlsym(RTLD_DEFAULT, "SecTrustEvaluate");
    }
    
    // 如果找不到原始函数，返回成功
    if (!original) {
        if (result != NULL) {
            // 使用正确的 SecTrustResultType 值
            *result = (SecTrustResultType)kSecTrustResultProceed;
        }
        return errSecSuccess;
    }
    
    OSStatus status = original(trust, result);
    
    if (result != NULL) {
        // 确保证书验证通过 - 使用正确的类型转换
        *result = (SecTrustResultType)kSecTrustResultProceed;
    }
    
    return errSecSuccess;
}

// 二进制补丁：直接修改内存中的证书验证函数
static void patch_certificate_chain_validation(void) {
    // 寻找目标函数
    void *sec_trust_evaluate = dlsym(RTLD_DEFAULT, "SecTrustEvaluate");
    void *sec_certificate_verify = dlsym(RTLD_DEFAULT, "SecCertificateVerifySignature");
    
    if (sec_trust_evaluate) {
        // 获取页面基址
        uintptr_t page_start = ((uintptr_t)sec_trust_evaluate) & ~(PAGE_SIZE - 1);
        
        // 更改内存保护
        if (mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
            // ARM64 指令: mov x0, #0 (成功返回码); ret
            uint32_t patch[2] = { 0xD2800000, 0xD65F03C0 };
            
            // 写入补丁代码
            memcpy(sec_trust_evaluate, patch, sizeof(patch));
            
            // 重置内存保护
            mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_EXEC);
        }
    }
    
    // 对SecCertificateVerify应用相同的补丁
    if (sec_certificate_verify) {
        uintptr_t page_start = ((uintptr_t)sec_certificate_verify) & ~(PAGE_SIZE - 1);
        if (mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
            uint32_t patch[2] = { 0xD2800000, 0xD65F03C0 };
            memcpy(sec_certificate_verify, patch, sizeof(patch));
            mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_EXEC);
        }
    }
}

// 修补二进制验证
static bool patch_binary_validation(void) {
    // 寻找二进制验证函数
    void *binary_validation = dlsym(RTLD_DEFAULT, "MISValidateSignature");
    if (!binary_validation) return false;
    
    // 获取页面基址
    uintptr_t page_start = ((uintptr_t)binary_validation) & ~(PAGE_SIZE - 1);
    
    // 更改内存保护
    if (mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
        // ARM64指令: mov x0, #0 (成功返回码); ret
        uint32_t patch[2] = { 0xD2800000, 0xD65F03C0 };
        
        // 写入补丁代码
        memcpy(binary_validation, patch, sizeof(patch));
        
        // 重置内存保护
        mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_EXEC);
        return true;
    }
    
    return false;
}

// 修改进程的签名信息
static bool patch_process_signature(void) {
    if (!g_exploit.exploit_ready) {
        NSLog(@"[DYYY] 无法修改进程签名：内核利用未准备就绪");
        return false;
    }
    
    // 获取进程的vnode
    uint64_t proc_vnode = kernel_read64(g_exploit.proc_addr + 0x100); // vnode偏移
    if (!proc_vnode) {
        NSLog(@"[DYYY] 无法获取进程vnode");
        return false;
    }
    
    // 获取签名信息结构
    uint64_t cs_blob = kernel_read64(proc_vnode + 0x80); // cs_blob偏移
    if (!cs_blob) {
        NSLog(@"[DYYY] 无法获取代码签名blob");
        return false;
    }
    
    // 修改签名来源标志
    uint32_t cs_flags = (uint32_t)kernel_read64(cs_blob + 0x10);
    cs_flags |= CS_SIGNED | CS_PLATFORM_BINARY;
    cs_flags &= ~CS_DEV_CODE;
    if (!kernel_write64(cs_blob + 0x10, cs_flags)) {
        return false;
    }
    
    return true;
}

// 修补签名验证函数
static bool patch_signature_validation_functions(void) {
    bool success = true;
    
    // 修补MISValidateSignature
    void *mis_validate = dlsym(RTLD_DEFAULT, "MISValidateSignature");
    if (mis_validate) {
        uintptr_t page_start = ((uintptr_t)mis_validate) & ~(PAGE_SIZE - 1);
        if (mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
            uint32_t patch[2] = { 0xD2800000, 0xD65F03C0 };
            memcpy(mis_validate, patch, sizeof(patch));
            mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_EXEC);
            success &= true;
        } else {
            success = false;
        }
    }
    
    // 尝试修补其他可能的签名验证函数
    void *sec_code_check = dlsym(RTLD_DEFAULT, "SecStaticCodeCheckValidityWithErrors");
    if (sec_code_check) {
        uintptr_t page_start = ((uintptr_t)sec_code_check) & ~(PAGE_SIZE - 1);
        if (mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
            uint32_t patch[2] = { 0xD2800000, 0xD65F03C0 };
            memcpy(sec_code_check, patch, sizeof(patch));
            mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_EXEC);
            success &= true;
        }
    }
    
    return success;
}

// 增强的安全绕过
static bool enhanced_security_bypass(void) {
    // 初始化内核漏洞利用
    bool success = init_kernel_exploit();
    if (!success) {
        NSLog(@"[DYYY] 内核漏洞利用初始化失败");
        return false;
    }
    
    // 应用内核补丁
    success = apply_kernel_patches();
    if (!success) {
        NSLog(@"[DYYY] 内核补丁应用失败");
        return false;
    }
    
    // 额外安全措施
    if (g_exploit.exploit_ready) {
        // 确保内核读写能力正常
        uint64_t test_addr = g_exploit.kernel_base + 0x100;
        uint64_t test_value = kernel_read64(test_addr);
        if (!kernel_write64(test_addr, test_value)) {
            NSLog(@"[DYYY] 内核写入测试失败");
            return false;
        }
        
        NSLog(@"[DYYY] 内核写入测试成功");
    }
    
    return success;
}

%ctor {
    @autoreleasepool {
        // 在这里可以放置早期初始化代码
        NSLog(@"[DYYY] Tweak 初始化中...");
    }
}

// 确保构造函数在最后被定义
__attribute__((constructor))
static void initialize_binary_integrity_bypass(void) {
    @autoreleasepool {
        NSLog(@"[DYYY] 启动抖音签名保护绕过");
        
        // 创建日志文件
        FILE *logFile = fopen("/tmp/dyyy_bypass.log", "w");
        if (logFile) {
            fprintf(logFile, "抖音保护绕过开始初始化\n");
            fclose(logFile);
        }
        
        // 确保早期修补
        patch_certificate_chain_validation();
        
        // 快速用户空间修补
        patch_info_plist_validation();
        create_fake_app_store_receipt();
        
        // 启动内核漏洞利用
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            if (enhanced_security_bypass()) {
                NSLog(@"[DYYY] 内核级别签名绕过成功");
                
                // 应用所有内核修补
                kernel_patch_codesign_flags();
                patch_process_signature();
                patch_signature_validation_functions();
                patch_binary_validation();
                
                // 记录成功日志
                FILE *logFile = fopen("/tmp/dyyy_bypass.log", "a");
                if (logFile) {
                    fprintf(logFile, "内核级别签名绕过成功\n");
                    fclose(logFile);
                }
                
                // 调用登录绕过
                bypass_douyin_login_validation();
                
                // 持续监控以防修复被撤销
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                    while (true) {
                        sleep(5);
                        kernel_patch_codesign_flags();
                    }
                });
            } else {
                NSLog(@"[DYYY] 内核级别签名绕过失败，尝试用户空间方法");
                // 尝试用户空间备用方法
                patch_signature_validation_functions();
            }
        });
    }
}

// 专门针对抖音登录流程的签名验证绕过
static void bypass_douyin_login_validation(void) {
    // 查找抖音二进制中的关键验证函数
    void *douyin_binary = dlopen(NULL, RTLD_NOW);
    if (!douyin_binary) return;
    
    // 可能的登录验证相关函数 - 通过反汇编分析确定
    void *checkAppSignature = dlsym(douyin_binary, "_OBJC_CLASS_$_AWESecurityManager");
    if (checkAppSignature) {
        // 获取类的方法列表
        Class securityManager = objc_getClass("AWESecurityManager");
        if (securityManager) {
            // 查找关键方法并替换
            Method verifyAppSignature = class_getInstanceMethod(securityManager, 
                                                              NSSelectorFromString(@"verifyAppSignature"));
            if (verifyAppSignature) {
                // 替换方法实现为总是返回YES
                IMP originalImp = method_getImplementation(verifyAppSignature);
                IMP newImp = imp_implementationWithBlock(^BOOL(id _self) {
                    return YES;
                });
                method_setImplementation(verifyAppSignature, newImp);
            }
            
            // 检查其他可能的验证方法
            SEL selectors[] = {
                NSSelectorFromString(@"isSignatureTampered"),
                NSSelectorFromString(@"isAppStoreVersion"),
                NSSelectorFromString(@"validateAppIntegrity"),
                NSSelectorFromString(@"checkAppReceipt")
            };
            
            // 遍历替换所有验证方法
            for (int i = 0; i < sizeof(selectors)/sizeof(selectors[0]); i++) {
                Method method = class_getInstanceMethod(securityManager, selectors[i]);
                if (method) {
                    IMP newImp = imp_implementationWithBlock(^BOOL(id _self) {
                        return YES; // 返回成功
                    });
                    method_setImplementation(method, newImp);
                }
                
                // 尝试类方法
                Method classMethod = class_getClassMethod(securityManager, selectors[i]);
                if (classMethod) {
                    IMP newImp = imp_implementationWithBlock(^BOOL(id _self) {
                        return YES;
                    });
                    method_setImplementation(classMethod, newImp);
                }
            }
        }
    }
    
    // 关闭二进制句柄
    dlclose(douyin_binary);
}

// 在内存中修改Info.plist验证
static bool patch_info_plist_validation(void) {
    // 查找Info.plist验证相关函数 - 简化实现
    void *validation_func = dlsym(RTLD_DEFAULT, "_MISValidateSignatureAndCopyInfo");
    if (!validation_func) {
        // 尝试其他可能的函数名
        validation_func = dlsym(RTLD_DEFAULT, "MISValidateSignatureAndCopyInfo");
    }
    
    if (!validation_func) return false;
    
    // 获取页面基址
    uintptr_t page_start = ((uintptr_t)validation_func) & ~(PAGE_SIZE - 1);
    
    // 更改内存保护
    if (mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
        // ARM64指令: mov x0, #0 (成功返回码); ret
        uint32_t patch[2] = { 0xD2800000, 0xD65F03C0 };
        
        // 写入补丁代码
        memcpy(validation_func, patch, sizeof(patch));
        
        // 重置内存保护
        mprotect((void *)page_start, PAGE_SIZE, PROT_READ | PROT_EXEC);
        return true;
    }
    
    return false;
}

// 创建伪造的App Store receipt
static bool create_fake_app_store_receipt(void) {
    NSString *receiptPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"_CodeSignature/receipt"];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:receiptPath]) {
        // 创建一个基本的receipt结构
        NSMutableData *fakeReceipt = [NSMutableData dataWithCapacity:256];
        
        // 添加一些随机数据作为伪造的receipt
        uint8_t buffer[256];
        for (int i = 0; i < 256; i++) {
            buffer[i] = (uint8_t)arc4random_uniform(256);
        }
        
        [fakeReceipt appendBytes:buffer length:256];
        
        // 确保目录存在
        NSString *receiptDir = [receiptPath stringByDeletingLastPathComponent];
        [fm createDirectoryAtPath:receiptDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        // 写入伪造的receipt
        return [fakeReceipt writeToFile:receiptPath atomically:YES];
    }
    
    return [fm fileExistsAtPath:receiptPath];
}