class Macvimswitch < Formula
  desc "Automatic input source switcher for Mac"
  homepage "https://github.com/jackiexiao/macvimswitch"
  url "https://github.com/jackiexiao/macvimswitch/archive/v1.0.0.tar.gz"
  sha256 "YOUR_TARBALL_SHA256"
  
  depends_on :xcode => :build
  depends_on :macos
  
  def install
    system "swiftc", "macvimswitch.swift", "-o", "macvimswitch"
    bin.install "macvimswitch"
    
    # 创建启动项配置
    (prefix/"Library/LaunchAgents/com.jackiexiao.macvimswitch.plist").write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>com.jackiexiao.macvimswitch</string>
        <key>Program</key>
        <string>#{opt_bin}/macvimswitch</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
      </dict>
      </plist>
    EOS
  end

  def post_install
    system "launchctl", "load", "#{prefix}/Library/LaunchAgents/com.jackiexiao.macvimswitch.plist"
  end
  
  def caveats
    <<~EOS
      MacVimSwitch has been installed and will start automatically on login.
      
      Important:
      1. You need to grant Accessibility permissions to the app
      2. Go to System Preferences -> Security & Privacy -> Privacy -> Accessibility
      3. Add and enable macvimswitch
      
      To start MacVimSwitch now, run:
        launchctl load #{prefix}/Library/LaunchAgents/com.jackiexiao.macvimswitch.plist
      
      To stop MacVimSwitch, run:
        launchctl unload #{prefix}/Library/LaunchAgents/com.jackiexiao.macvimswitch.plist
    EOS
  end
end 