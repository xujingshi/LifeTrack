# LifeTrack iOS 项目指南

## 项目概述

LifeTrack 是一个个人生活管理 iOS 应用，用于习惯打卡、日记记录、计划管理和快速笔记。

## 技术栈

- **语言**: Swift 5.9+
- **UI框架**: SwiftUI
- **最低支持**: iOS 17.0
- **架构**: 单层 View + Service（无 MVVM ViewModel）
- **网络**: URLSession + async/await
- **图表**: Swift Charts

## 项目结构

```
LifeTrack/
├── App/
│   └── LifeTrackApp.swift          # 应用入口
├── Models/                          # 数据模型
│   ├── CheckIn.swift               # 打卡相关模型
│   ├── Diary.swift                 # 日记模型
│   ├── Plan.swift                  # 计划模型
│   ├── QuickNote.swift             # 快速笔记模型
│   └── User.swift                  # 用户模型
├── Services/                        # 网络服务
│   ├── APIService.swift            # 基础 API 服务
│   ├── AuthManager.swift           # 认证管理
│   ├── CheckInService.swift        # 打卡服务
│   ├── DiaryService.swift          # 日记服务
│   ├── PlanService.swift           # 计划服务
│   └── QuickNoteService.swift      # 快速笔记服务
└── Views/                           # 视图层
    ├── Auth/                        # 登录注册
    ├── CheckIn/                     # 打卡功能
    │   ├── CheckInView.swift       # 打卡主页
    │   ├── CheckInCalendarView.swift
    │   ├── CheckInItemDetailView.swift
    │   ├── CheckInStatisticsView.swift
    │   └── CheckInOverallStatisticsView.swift
    ├── Diary/                       # 日记功能
    │   └── DiaryListView.swift
    ├── Plan/                        # 计划功能
    │   └── PlanListView.swift
    ├── QuickNote/                   # 快速笔记
    │   └── QuickNoteView.swift
    └── ContentView.swift            # 主 TabView
```

## 核心功能模块

### 1. 打卡 (CheckIn)
- 支持普通打卡、图片打卡、数值打卡三种类型
- 重复类型：每天、工作日、周末、自定义、间隔天数、自由记录
- 日历视图展示打卡历史
- 统计图表（周/月/年）

### 2. 日记 (Diary)
- 支持标题、内容、心情、天气
- 多图片上传
- 日历视图
- 全文搜索

### 3. 计划 (Plan)
- 支持计划和任务两级结构
- 任务状态：待办、进行中、已完成、已取消
- 截止日期管理

### 4. 快速笔记 (QuickNote)
- 语音输入（Speech 框架）
- 快速记录想法

## API 配置

后端服务地址配置在 `APIService.swift`:
```swift
private let baseURL = "http://localhost:8080/api/v1"
```

## 关键数据模型

### CheckInItem (打卡项)
```swift
struct CheckInItem {
    let id: Int
    let name: String
    let repeatType: Int      // 0=每天, 1=工作日, 2=周末, 3=自定义, 4=间隔, 5=自由
    let checkType: Int?      // 0=普通, 1=图片, 2=数值
    let valueUnit: String?   // 数值单位
}
```

### RepeatType 枚举
- `.daily` (0): 每天
- `.weekday` (1): 工作日 (周一至周五)
- `.weekend` (2): 周末
- `.custom` (3): 自定义 (repeatDays 存储选中的星期)
- `.interval` (4): 间隔天数
- `.free` (5): 自由记录

## 已知问题和待优化

### 高优先级
1. **Token 存储安全**: 当前使用 UserDefaults 存储，应改用 Keychain
2. **日期跨天处理**: 应用在后台时可能不会更新日期

### 中优先级
1. **代码复用**: 日期解析逻辑在多个文件中重复
2. **MVVM 改造**: 当前业务逻辑都在 View 中，应抽取 ViewModel
3. **错误处理**: 部分地方使用 `try?` 忽略错误

### 低优先级
1. 添加单元测试
2. 实现本地缓存
3. 性能优化（图片缓存、列表渲染）

## 常用命令

### 构建
```bash
xcodebuild -project LifeTrack.xcodeproj -scheme LifeTrack -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### 部署到模拟器
```bash
xcrun simctl install booted /path/to/LifeTrack.app
xcrun simctl launch booted com.xujingshi.LifeTrack
```

## 开发注意事项

1. 所有 API 请求都需要 JWT Token（除了登录注册）
2. 日期格式统一使用 `yyyy-MM-dd`
3. 时间格式使用 `HH:mm`
4. 服务端返回的时间戳可能带微秒和时区，解析时需兼容多种格式
5. 打卡项的 `repeatDays` 字段存储格式为逗号分隔的数字字符串（如 "1,3,5" 表示周一三五）
