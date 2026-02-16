# LifeTrack iOS App

自律打卡 & 日记 App 的 iOS 前端，使用 SwiftUI 开发。

## 功能特性

- **规划管理**: 创建、编辑、删除待办事项，支持优先级和状态管理
- **自律打卡**: 每日打卡项管理，支持多种重复规则，日历视图查看完成情况
- **图文日记**: 写日记支持心情、天气记录，支持图片上传和全文搜索

## 项目结构

```
LifeTrack/
├── App/
│   ├── LifeTrackApp.swift      # App 入口
│   └── MainTabView.swift       # 主 Tab 视图
├── Models/
│   ├── User.swift              # 用户模型
│   ├── Plan.swift              # 规划模型
│   ├── CheckIn.swift           # 打卡模型
│   ├── Diary.swift             # 日记模型
│   └── APIResponse.swift       # API 响应模型
├── Services/
│   ├── APIService.swift        # API 服务
│   ├── AuthManager.swift       # 认证管理
│   ├── PlanService.swift       # 规划服务
│   ├── CheckInService.swift    # 打卡服务
│   └── DiaryService.swift      # 日记服务
└── Views/
    ├── Auth/
    │   └── LoginView.swift     # 登录/注册视图
    ├── Plan/
    │   └── PlanListView.swift  # 规划列表视图
    ├── CheckIn/
    │   └── CheckInView.swift   # 打卡视图
    └── Diary/
        └── DiaryListView.swift # 日记列表视图
```

## 如何使用

### 方法一：使用 Xcode 创建项目

1. 打开 Xcode，选择 "Create a new Xcode project"
2. 选择 iOS > App
3. 填写项目信息：
   - Product Name: LifeTrack
   - Organization Identifier: com.yourname
   - Interface: SwiftUI
   - Language: Swift
4. 选择保存位置为 `~/go/src/github.com/xujingshi/`
5. 将本目录下的 `LifeTrack/` 文件夹中的所有文件复制到 Xcode 项目中

### 方法二：手动创建项目

1. 在 Xcode 中创建新的 SwiftUI 项目
2. 删除默认生成的文件
3. 添加本目录下的所有 Swift 文件到项目中
4. 确保文件组织结构正确

## 配置说明

### API 地址配置

在 `Models/APIResponse.swift` 中修改 API 地址：

```swift
struct APIConfig {
    static let baseURL = "http://localhost:8080"  // 开发环境
    // static let baseURL = "https://api.yourserver.com"  // 生产环境
    static let apiVersion = "/api/v1"
}
```

### 运行要求

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## 主要依赖

- SwiftUI（原生 UI 框架）
- Combine（响应式编程）
- URLSession（网络请求）

## 截图预览

### 登录页面
- 简洁的登录表单
- 支持注册新账号

### 规划页面
- 列表展示所有规划
- 支持状态切换（点击图标）
- 左滑删除

### 打卡页面
- 今日打卡统计
- 打卡项列表
- 点击即可完成打卡

### 日记页面
- 日记列表（按日期排序）
- 支持全文搜索
- 心情和天气记录

## 注意事项

1. 确保后端服务已启动（默认 http://localhost:8080）
2. iOS 模拟器访问本地服务时使用 localhost
3. 真机测试需要修改 API 地址为实际服务器地址
4. 图片上传需要后端服务支持
