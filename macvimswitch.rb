class Macvimswitch < Formula
  desc "Automatic input source switcher for Mac"
  homepage "https://github.com/jackiexiao/macvimswitch"
  version "PLACEHOLDER_VERSION"  # 将在 GitHub Actions 中替换

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/jackiexiao/macvimswitch/releases/download/v#{version}/MacVimSwitch-arm64.zip"
      sha256 "PLACEHOLDER_ARM64_SHA256"
    else
      url "https://github.com/jackiexiao/macvimswitch/releases/download/v#{version}/MacVimSwitch-x86_64.zip"
      sha256 "PLACEHOLDER_X86_64_SHA256"
    end
  end

  depends_on :macos

  def install
    if OS.mac?
      if Hardware::CPU.arm?
        bin.install "MacVimSwitch.app/Contents/MacOS/macvimswitch" => "macvimswitch"
      else
        bin.install "MacVimSwitch.app/Contents/MacOS/macvimswitch" => "macvimswitch"
      end
    end

    # Install launch agent
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