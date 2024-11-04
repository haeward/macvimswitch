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
      unless Dir.exist?("dist/MacVimSwitch.app")
        odie "MacVimSwitch.app not found in the expected location"
      end
      
      prefix.install Dir["dist/MacVimSwitch.app"]
      
      app_path = prefix/"MacVimSwitch.app"
      unless File.exist?(app_path)
        odie "Failed to install MacVimSwitch.app"
      end
      
      bin_path = app_path/"Contents/MacOS/macvimswitch"
      unless File.exist?(bin_path)
        odie "Executable not found in app bundle"
      end
      
      bin.install_symlink bin_path => "macvimswitch"
    end
  end

  def post_install
    # 添加到登录项
    system "osascript", "-e", <<~APPLESCRIPT
      tell application "System Events"
        make new login item at end with properties {path:"/Applications/MacVimSwitch.app", hidden:false}
      end tell
    APPLESCRIPT
  end
  
  def caveats
    <<~EOS
      MacVimSwitch has been installed and configured to start at login.
      
      Important:
      1. You need to grant Accessibility permissions to the app
      2. Go to System Preferences -> Security & Privacy -> Privacy -> Accessibility
      3. Add and enable macvimswitch
      
      To start MacVimSwitch now, run:
        macvimswitch
      
      To stop MacVimSwitch:
      - Click the keyboard icon in the menu bar
      - Select "Quit"
      
      You can enable/disable launch at login from the menu bar icon.
      
      Or use command line:
        pkill macvimswitch
    EOS
  end

  # 添加测试方法
  test do
    system "#{bin}/macvimswitch", "--version"
  end
end 