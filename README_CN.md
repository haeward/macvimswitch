# MacVimSwitch

[English](README.md) | [中文说明](README_CN.md)

MacVimSwitch 是一个 macOS 输入法切换工具，专为 Vim 用户和经常需要切换输入法的用户设计。

## 功能特点

- 按 ESC 键时自动切换到英文输入法
- 后台运行，状态栏显示图标
- 可选功能：使用 Shift 键切换输入法
- 温馨提示：在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
- 系统登录时自动启动

## 安装方法

使用 Homebrew 安装：
```bash
brew tap jackiexiao/tap      # 添加软件源到 Homebrew
brew install macvimswitch    # 安装 MacVimSwitch
```

或从源码编译：
```bash
git clone https://github.com/jackiexiao/macvimswitch
cd macvimswitch
swiftc macvimswitch.swift -o macvimswitch
```

## 使用方法

1. 安装后需要授予辅助功能权限：
   - 打开系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能
   - 添加并启用 macvimswitch

2. 程序会在系统登录时自动启动
3. 点击状态栏的键盘图标可以：
   - 查看使用说明
   - 退出应用程序

## 注意事项

1. 如果启用了 Shift 键切换功能，请确保关闭输入法中的"使用 Shift 切换中英文"选项
2. 程序需要辅助功能权限才能正常工作
3. 授予权限后可能需要重启系统

## 开发者指南

### 发布流程

1. 创建 GitHub 仓库
```bash
# 1. 在 github.com/jackiexiao/macvimswitch 创建新仓库
# 2. 克隆并初始化仓库
git clone https://github.com/jackiexiao/macvimswitch.git
cd macvimswitch
```

2. 准备发布文件
```bash
# 添加所有必要文件
git add macvimswitch.swift README.md README_CN.md LICENSE
git commit -m "Initial commit"
git push origin main
```

3. 创建发布版本
```bash
# 标记版本
git tag v1.0.0
git push origin v1.0.0

# 在 GitHub 上：
# 1. 进入仓库 → Releases → Create a new release
# 2. 选择 v1.0.0 标签
# 3. 标题：MacVimSwitch v1.0.0
# 4. 生成发布说明
# 5. 发布
```

4. 创建 Homebrew Tap
```bash
# 1. 创建新仓库：github.com/jackiexiao/homebrew-tap
# 2. 克隆仓库
git clone https://github.com/jackiexiao/homebrew-tap.git
cd homebrew-tap

# 3. 计算发布包的 SHA256 值
curl -L https://github.com/jackiexiao/macvimswitch/archive/v1.0.0.tar.gz | shasum -a 256

# 4. 更新 macvimswitch.rb 中的 SHA256
# 5. 提交并推送 formula
git add macvimswitch.rb
git commit -m "添加 MacVimSwitch formula"
git push origin main
```

### 本地开发

本地构建和测试：
```bash
swiftc macvimswitch.swift -o macvimswitch
./macvimswitch
```

### 贡献代码

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m '添加某个很棒的特性'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 提交 Pull Request

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。 