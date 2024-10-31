# MacVimSwitch

[English](README.md) | [中文说明](README_CN.md)

MacVimSwitch is a utility for macOS that automatically switches input sources, designed specifically for Vim users and those who frequently switch between input methods.

## Features

- Automatically switches to ABC input method when pressing ESC
- Runs in the background with a status bar icon
- Optional feature: Use Shift key to switch input methods, you need to manually switch the input method once before using it and disable the "Use Shift to switch between English and Chinese" option in the Chineseinput method settings
- Reminder about CapsLock behavior on Mac: short press to switch input method, long press for caps lock
- Auto-starts on system login

## Installation

```bash
brew tap jackiexiao/tap      # Add the repository to Homebrew
brew install macvimswitch    # Install MacVimSwitch
```

Or build from source:
```bash
git clone https://github.com/jackiexiao/macvimswitch
cd macvimswitch
swiftc macvimswitch.swift -o macvimswitch
```

## Usage

1. After installation, grant Accessibility permissions:
   - Go to System Preferences → Security & Privacy → Privacy → Accessibility
   - Add and enable macvimswitch

2. Important setup before first use:
   - Manually switch between your Chinese input method and ABC input method once
   - This helps the system remember your Chinese input method and ensures the Shift switching feature works properly

3. The app will automatically start on system login
4. Click the keyboard icon in the status bar to:
   - View instructions
   - Enable/Disable Shift key switching
   - Quit the application

## Important Notes

1. If you enable the Shift key switching feature, make sure to disable the "Use Shift to switch between English and Chinese" option in your input method settings
2. The app requires accessibility permissions to function properly
3. A system restart might be required after granting permissions

## For Developers

### How to Release

1. Create GitHub Repository
```bash
# 1. Create a new repository at github.com/jackiexiao/macvimswitch
# 2. Clone and initialize the repository
git clone https://github.com/jackiexiao/macvimswitch.git
cd macvimswitch
```

2. Prepare Release Files
```bash
# Add all necessary files
git add macvimswitch.swift README.md README_CN.md LICENSE
git commit -m "Initial commit"
git push origin main
```

3. Create Release
```bash
# Tag the release
git tag v1.0.0
git push origin v1.0.0

# On GitHub:
# 1. Go to repository → Releases → Create a new release
# 2. Choose the v1.0.0 tag
# 3. Title: MacVimSwitch v1.0.0
# 4. Generate release notes
# 5. Publish release
```

4. Create Homebrew Tap
```bash
# 1. Create a new repository: github.com/jackiexiao/homebrew-tap
# 2. Clone the repository
git clone https://github.com/jackiexiao/homebrew-tap.git
cd homebrew-tap

# 3. Calculate SHA256 of the release tarball
curl -L https://github.com/jackiexiao/macvimswitch/archive/v1.0.0.tar.gz | shasum -a 256

# 4. Update the SHA256 in macvimswitch.rb
# 5. Commit and push the formula
git add macvimswitch.rb
git commit -m "Add MacVimSwitch formula"
git push origin main
```

### Development

To build and test locally:
```bash
swiftc macvimswitch.swift -o macvimswitch
./macvimswitch
```

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
