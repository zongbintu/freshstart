# Windows PC Setup

On your new Windows 11 PC, open **PowerShell as administrator** under your own Windows account and change to the directory containing the script. Use the built-in 64-bit Windows PowerShell 5.1. If `winget --version` fails, install or update App Installer from the Microsoft Store.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

The first command previews the installation list. The second installs all listed software. The execution policy override applies only to the PowerShell process started by each command. WinGet automatically accepts package and source agreements. The script prompts you to review the Android SDK licenses in the terminal. If you have already read and accepted them, add `-AcceptAndroidLicenses` to the installation command to answer the prompts automatically.

The script installs Git, the latest stable Python 3, Temurin JDK 21 LTS, Gradle 9.9.2, the Android SDK, the ChatGPT Windows desktop app with Codex, the standalone Codex CLI, Feishu, WeChat, Chrome, NetBird, [Magpie by yetone](https://github.com/yetone/magpie), Clash Verge Rev, GitHub CLI, Node.js LTS (including npm), Bun, Notepad++, RTK (Rust Token Killer), the Feishu CLI (`lark-cli`), PuTTY, the Sogou Wubi input method, DBeaver Community, and Paseo Desktop.

- The official Python Install Manager selects and updates the default stable CPython release. The script downloads pinned versions of Gradle and the Android command-line tools from their official sources and verifies both archives against their SHA-256 checksums.
- WinGet installs RTK, PuTTY, and Sogou Wubi. The script installs `lark-cli` globally with npm and adds npm's global command directory to the current user's `Path`.
- The script downloads Magpie's Windows desktop executable for x64 or ARM64 from the official GitHub release, verifies its SHA-256 digest, and creates a **Magpie (yetone)** Start menu shortcut.
- The Android SDK defaults to `%LOCALAPPDATA%\Android\Sdk`. The script reuses an existing path from `ANDROID_HOME` or `ANDROID_SDK_ROOT`, in that order. It installs `platform-tools` (including `adb`), API 36, and Build Tools 36.0.0.
- The script sets `JAVA_HOME` and `ANDROID_HOME` for the current user, adds the required directories to `Path`, and prints an installation summary. If an item fails, the script continues with the remaining items and returns exit code `1` at the end. WinGet skips upgrades for packages that are already installed.

To install selected items or retry failed ones, run the script directly from PowerShell with `-Only` and one or more names from the `-DryRun` output. Selecting Gradle or the Android SDK also selects the JDK. Selecting `LarkCLI` also selects Node.js LTS.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup.ps1 -Only Git, Python, CodexCLI
.\setup.ps1 -Only AndroidSDK -AcceptAndroidLicenses
.\setup.ps1 -Only Node, Bun
.\setup.ps1 -Only NotepadPP
.\setup.ps1 -Only RTK, LarkCLI, PuTTY, SogouWubi
.\setup.ps1 -Only DBeaver
.\setup.ps1 -Only Magpie
.\setup.ps1 -Only Paseo
```

After installation, reopen your terminal. Follow the sign-in prompts for apps that require an account, such as Codex, GitHub CLI, Feishu, WeChat, and NetBird. Before using `lark-cli` for the first time, run `lark-cli config init` to configure the app, then run `lark-cli auth login --recommend` to sign in.
