# HealthKit 配置说明

## 需要在 Xcode 中进行以下配置：

### 1. 添加 HealthKit 能力
1. 在 Xcode 中打开项目
2. 选择项目的 Target
3. 点击 "Signing & Capabilities" 标签
4. 点击 "+ Capability" 按钮
5. 搜索并添加 "HealthKit"

### 2. 添加隐私说明
在项目的 Info.plist 文件中添加以下内容：

```xml
<key>NSHealthShareUsageDescription</key>
<string>我们需要访问您的健康数据以导入血压记录</string>
```

或者在 Xcode 的 Info 标签中添加：
- Key: Privacy - Health Share Usage Description
- Value: 我们需要访问您的健康数据以导入血压记录

### 3. 注意事项
- HealthKit 仅在真实设备上可用，模拟器不支持
- 用户需要在健康App中有血压数据才能导入
- 首次运行时会请求用户授权
