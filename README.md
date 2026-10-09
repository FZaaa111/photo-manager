# Photo Manager

一款 iOS 相册整理工具：自动找出**相似照片**、**模糊照片**和**体积较大的视频**，让你用最少的操作释放手机存储空间。

> **状态：功能开发完成，待真机验证** —— 大视频筛选、模糊照片、相似照片合并、重复照片检测、相册健康检查均已有初版实现。代码在无 Xcode 的环境中编写，编译与算法阈值（模糊分数、相似度）需要在 Mac / 真机上验证和调参，见下方"验证清单"。

## 功能

### 1. 相似照片合并
- 识别连拍、同一场景多次拍摄、重复保存等相似照片，并按组展示。
- 每组自动推荐一张"最佳照片"（清晰度、人脸质量、是否收藏、分辨率综合评分），其余标记为可删除。
- 支持手动更换保留项，一键"保留最佳 / 删除其余"；合并时被删照片的收藏状态和所属相册会并入保留项。
- 可调节相似度阈值（严格 / 标准 / 宽松）。

### 重复照片检测
- 先按文件大小 + 像素尺寸预分桶，只对可能重复的照片读取原图并计算 SHA256，内容完全一致才算重复。
- 默认保留收藏的、最早创建的那一张；支持手动更换保留项，一键合并全部。

### 相册健康检查（首页）
- 汇总照片/视频数量、截图、屏幕录制、连拍、实况、全景数量，以及空相册。
- 给出清理建议：大视频总体积、疑似模糊照片数、空相册等，并直接跳转到对应清理页。
- 支持一键删除空相册（只删相册本身，不影响照片）。

### 2. 模糊照片清理
- 检测对焦失败、抖动、运动模糊等不清晰的照片，按模糊程度从高到低排序。
- 提供阈值滑块，实时预览哪些照片会被判定为模糊。
- 支持多选、批量删除，也可以把误判的照片加入"忽略列表"。

### 3. 大体积视频清理
- 列出相册中所有视频，按文件大小降序排列，并显示可释放的总空间。
- 支持按大小（如 > 100 MB）、时长、拍摄时间筛选。
- 筛选条件：最小体积（50MB/100MB/500MB/1GB）、最短时长、拍摄日期早于某天；支持多种排序。
- 支持多选批量删除；后续版本计划支持"压缩后保留"。

### 通用
- **安全删除**：所有删除操作都走系统相册的删除流程，照片进入"最近删除"，30 天内可恢复。
- **隐私优先**：所有分析均在设备本地完成，不上传任何照片或元数据。
- **增量扫描**：首次全量扫描后，只处理新增/变更的资源；扫描可在后台暂停和恢复。
- 预估可释放空间统计与清理前后对比。

## 技术方案

| 模块 | 方案 |
| --- | --- |
| 相册访问 | `Photos` 框架（`PHAsset` / `PHPhotoLibrary` / `PHCachingImageManager`），申请读写权限；支持"有限访问"模式 |
| 相似检测 | 先用感知哈希（dHash/pHash）或拍摄时间窗口做粗分组，再用 `Vision` 的 `VNGenerateImageFeaturePrintRequest` 计算特征向量距离，聚类成组 |
| 模糊检测 | 对缩略图做灰度化 + 拉普拉斯算子，取方差作为清晰度分数（`Accelerate` / `Core Image`），低于阈值判定为模糊；可选 `Vision` 人脸质量分作为补充 |
| 最佳照片评分 | 清晰度分数 + `VNDetectFaceCaptureQualityRequest` 人脸质量 + 系统收藏/编辑状态加权 |
| 视频体积 | 读取 `PHAssetResource` 的文件大小，结合时长、分辨率展示 |
| 删除 | `PHAssetChangeRequest.deleteAssets(_:)`，由系统弹出确认框 |
| 本地缓存 | `SwiftData`（或 Core Data）保存扫描结果：特征向量、清晰度分数、已忽略项 |
| 并发 | Swift Concurrency（`async/await` + `TaskGroup`）限流并行处理，控制内存与发热 |
| UI | `SwiftUI` |

### 需要注意的问题
- **iCloud 照片**：开启"优化 iPhone 储存空间"后，原图可能不在本地。分析优先使用本地缩略图；需要原图时再按用户设置决定是否允许网络下载。
- **性能与耗电**：大相册（数万张）需分批、低优先级处理，并提供进度与暂停。
- **误判**：模糊/相似都是启发式判断，因此始终需要用户确认后才删除，不做自动静默删除。
- **隐私权限**：需要在 `Info.plist` 中声明 `NSPhotoLibraryUsageDescription` 与 `NSPhotoLibraryAddUsageDescription`。

## 环境要求

- Xcode 15 或更高版本
- iOS 17.0+（使用 SwiftData；若改用 Core Data 可下探至 iOS 16）
- Swift 5.9+
- 真机测试（模拟器相册数据有限，且无法验证性能）

## 快速开始

工程使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 由 `project.yml` 生成，`.xcodeproj` 不入库，避免合并冲突。

```bash
brew install xcodegen
xcodegen generate        # 生成 PhotoManager.xcodeproj 和 Config/Info.plist
open PhotoManager.xcodeproj
```

1. 在 target 的 *Signing & Capabilities* 中选择你的开发团队，并按需修改 `project.yml` 里的 `com.example.PhotoManager`。
2. 连接真机运行（模拟器相册数据有限，无法验证性能）。
3. 运行单元测试：`⌘U`，或
   `xcodebuild test -scheme PhotoManager -destination 'platform=iOS Simulator,name=iPhone 15'`。

> 修改 `project.yml` 或新增/删除源文件后，重新执行 `xcodegen generate`。

## 项目结构

```
photo-manager/
├── project.yml                  # XcodeGen 工程定义（含 Info.plist 权限文案）
├── .github/workflows/ios.yml    # macOS CI：生成工程、编译、跑单元测试
├── PhotoManager/
│   ├── App/                     # 入口、AppServices（SwiftData 容器 / 扫描流水线）、权限引导
│   ├── Features/
│   │   ├── Dashboard/           # 相册健康检查、清理入口、空相册管理
│   │   ├── LargeVideos/         # 大视频清理 + VideoFilter 筛选
│   │   ├── Blurry/              # 模糊照片清理（阈值滑块、忽略列表）
│   │   ├── Similar/             # 相似照片合并
│   │   ├── Duplicates/          # 重复照片检测
│   │   └── Shared/              # 分组列表 / 详情、网格、扫描进度等共用 UI
│   ├── Core/
│   │   ├── Analysis/            # 纯算法：GrayImage、BlurDetector、PerceptualHash、
│   │   │                        #   SimilarGrouper、DuplicateGrouper、BestPhotoPicker；
│   │   │                        #   以及 Vision / CryptoKit 封装
│   │   ├── Storage/             # SwiftData 缓存：AssetRecord、IgnoredAsset、RecordStore
│   │   ├── Scan/                # ScanPipeline：增量扫描、限流并行、可取消
│   │   ├── Library/             # PhotoKit 封装、缩略图、相册健康检查
│   │   ├── Deletion/            # 删除与合并（同一次 performChanges）
│   │   └── Formatters.swift
│   └── Resources/Assets.xcassets
├── PhotoManagerTests/           # 算法、筛选、缓存、报告的单元测试
└── README.md
```

## 实现要点

- **增量扫描**：以 `localIdentifier` 为键、`modificationDate` 为失效依据，把清晰度、dHash、特征向量、文件哈希缓存到 SwiftData。再次扫描只处理新增或被编辑过的照片。
- **相似检测流程**：按拍摄时间排序，只在时间窗口内比较（严格 30 秒 / 标准 2 分钟 / 宽松 10 分钟）→ 连拍或 dHash 粗筛 → 仅对候选计算 Vision 特征向量并比距离 → 并查集聚类。
- **模糊检测**：256px 灰度图的 3×3 拉普拉斯方差。截图、白墙等低纹理画面分数天然偏低，因此默认不含截图，并提供"忽略"。
- **iCloud**：分析只用本地可得的缩略图，不触发网络下载。
- **删除**：全部走 `PHPhotoLibrary.performChanges`；合并时把"并入收藏 / 相册"和"删除"放在同一次变更里，用户在系统弹窗点取消则整体不生效。

## 验证清单（需 Mac / 真机）

代码尚未在 Xcode 中编译。拉取后建议：

1. `xcodegen generate` 后先编译并运行单元测试（`⌘U`），修复可能出现的编译错误。
2. 真机验证：授权 / 有限访问；千级以上相册的首次扫描与二次增量扫描耗时；iCloud 优化存储下的行为；删除取消后的状态；合并后收藏与相册归属。
3. 调参：`BlurryFilter.defaultThreshold`（模糊分数）与 `SimilarityLevel`（`maxHashDistance` / `maxFeatureDistance` / `timeWindow`）目前是经验初值，需要用真实相册调整。
4. `fileSize` 通过 `PHAssetResource` 的 KVC 读取（未文档化接口），读取失败时回退为 0，对应的可释放空间会显示偏小。

## 开发路线

- [x] **M0**：工程搭建、相册权限、资源列表与缩略图加载
- [x] **M1**：大视频列表、排序、筛选与批量删除
- [x] **M2**：模糊照片检测与清理（待真机调参）
- [x] **M3**：相似照片分组、最佳照片推荐与合并；重复照片检测（待真机调参）
- [x] **M4**：增量扫描与 SwiftData 缓存；相册健康检查。后台处理（BGProcessingTask）与进一步性能优化待做
- [ ] **M5**：视频压缩、忽略列表、本地化（中/英）、App Store 上架准备

## 隐私声明

本应用不会收集、上传或分享你的任何照片、视频及相关数据。所有识别与分析均在设备本地完成。

## 贡献

欢迎提交 Issue 与 Pull Request。

## 许可证

待定（TBD）。
