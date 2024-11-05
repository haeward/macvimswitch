#!/bin/bash

# 清理旧的构建
rm -rf dist

# 创建目录结构
mkdir -p dist/MacVimSwitch.app/Contents/{MacOS,Resources,Frameworks}

# 编译
swiftc -o dist/MacVimSwitch.app/Contents/MacOS/macvimswitch macvimswitch.swift \
    -framework Cocoa \
    -framework Carbon \
    -target arm64-apple-macos11 \
    -O \
    -whole-module-optimization \
    -Xlinker -rpath \
    -Xlinker @executable_path/../Frameworks

# 创建 Info.plist
cat > dist/MacVimSwitch.app/Contents/Info.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>macvimswitch</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.jackiexiao.macvimswitch</string>
    <key>CFBundleName</key>
    <string>MacVimSwitch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacVimSwitch needs to control system events to manage input sources.</string>
    <key>NSAppleScriptEnabled</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <false/>
    <key>NSAccessibilityUsageDescription</key>
    <string>MacVimSwitch needs accessibility access to monitor keyboard events.</string>
</dict>
</plist>
EOL

# 创建 entitlements.plist
cat > entitlements.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.temporary-exception.apple-events</key>
    <array>
        <string>com.apple.systemevents</string>
    </array>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOL

# 设置执行权限
chmod +x dist/MacVimSwitch.app/Contents/MacOS/macvimswitch

# 签名应用（使用 entitlements）
codesign --force --deep --sign - --entitlements entitlements.plist dist/MacVimSwitch.app

echo "Build complete! App is in dist/MacVimSwitch.app"
echo "You can now run: open dist/MacVimSwitch.app"