#!/bin/bash

# 清理旧的构建
rm -rf dist

# 创建目录结构
mkdir -p dist/MacVimSwitch.app/Contents/{MacOS,Resources}

# 构建通用二进制
swiftc -o dist/MacVimSwitch.app/Contents/MacOS/macvimswitch macvimswitch.swift \
  -framework Cocoa \
  -framework Carbon \
  -target arm64-apple-macos11 \
  -target x86_64-apple-macos11 \
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

# 使用自签名
codesign --force --deep --sign - --entitlements entitlements.plist dist/MacVimSwitch.app

# 创建 DMG（可选）
if [ "$1" = "--create-dmg" ]; then
    # 创建临时挂载点
    mkdir -p /tmp/dmg
    
    # 创建应用程序文件夹符号链接
    ln -s /Applications /tmp/dmg/Applications
    
    # 复制应用
    cp -r dist/MacVimSwitch.app /tmp/dmg/
    
    # 创建 DMG
    hdiutil create -volname "MacVimSwitch" -srcfolder /tmp/dmg -ov -format UDZO MacVimSwitch.dmg
    
    # 清理
    rm -rf /tmp/dmg
    
    echo "DMG created: MacVimSwitch.dmg"
fi

echo "Build complete! App is in dist/MacVimSwitch.app"
echo "You can now run: open dist/MacVimSwitch.app"