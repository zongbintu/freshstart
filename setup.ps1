#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Git', 'Python', 'JDK', 'Gradle', 'AndroidSDK', 'CodexDesktop', 'CodexCLI',
        'Feishu', 'WeChat', 'Chrome', 'NetBird', 'Magpie', 'ClashVerge', 'GitHubCLI',
        'Node', 'Bun', 'NotepadPP', 'RTK', 'LarkCLI', 'PuTTY', 'SogouWubi', 'DBeaver', 'Paseo')]
    [string[]]$Only,

    [switch]$DryRun,
    [switch]$AcceptAndroidLicenses
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$store = 'msstore'
$community = 'winget'
$packages = [ordered]@{
    Git          = @('Git.Git', $community)
    Python       = @('9NQ7512CXL7T', $store)
    JDK          = @('EclipseAdoptium.Temurin.21.JDK', $community)
    Gradle       = @()
    AndroidSDK   = @()
    CodexDesktop = @('9PLM9XGG6VKS', $store)
    CodexCLI     = @('OpenAI.Codex', $community)
    Feishu       = @('ByteDance.Feishu', $community)
    WeChat       = @('Tencent.WeChat.Universal', $community)
    Chrome       = @('Google.Chrome', $community)
    NetBird      = @('Netbird.Netbird', $community)
    Magpie       = @()
    ClashVerge   = @('ClashVergeRev.ClashVergeRev', $community)
    GitHubCLI    = @('GitHub.cli', $community)
    Node         = @('OpenJS.NodeJS.LTS', $community)
    Bun          = @('Oven-sh.Bun', $community)
    NotepadPP    = @('Notepad++.Notepad++', $community)
    RTK          = @('rtk-ai.rtk', $community)
    LarkCLI      = @()
    PuTTY        = @('PuTTY.PuTTY', $community)
    SogouWubi    = @('Sogou.SogouWBInput', $community)
    DBeaver      = @('DBeaver.DBeaver.Community', $community)
    Paseo        = @('Paseo.Paseo', $community)
}
$gradleVersion = '9.9.2'
$androidTools = 'commandlinetools-win-15859902_latest.zip'
$androidPackages = @('platform-tools', 'platforms;android-36', 'build-tools;36.0.0')
$sdkRoot = [Environment]::GetEnvironmentVariable('ANDROID_HOME')
if (-not $sdkRoot) { $sdkRoot = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT') }
if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

if ($Only -contains 'Gradle' -or $Only -contains 'AndroidSDK') { $Only += 'JDK' }
if ($Only -contains 'LarkCLI') { $Only += 'Node' }
$selected = @($packages.Keys | Where-Object { -not $Only -or $_ -in $Only })

if ($DryRun) {
    foreach ($name in $selected) {
        $description = $packages[$name] -join ' / '
        switch ($name) {
            Python { $description += ' + latest stable CPython' }
            Gradle { $description = "Gradle $gradleVersion (official ZIP)" }
            AndroidSDK { $description = "$sdkRoot | $($androidPackages -join ', ')" }
            Magpie { $description = 'yetone/magpie desktop app / official GitHub release' }
            LarkCLI { $description = '@larksuite/cli / npm' }
        }
        Write-Host ("{0,-13} {1}" -f $name, $description)
    }
    return
}

$winGet = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
if (-not $winGet) { throw 'WinGet is required. Install or update App Installer from Microsoft Store.' }

function Add-UserPath {
    param([string]$Directory)

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if ($Directory -notin $entries) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $Directory) -join ';'), 'User')
    }
    if ($Directory -notin ($env:Path -split ';')) { $env:Path = "$Directory;$env:Path" }
}

function Install-WinGetPackage {
    param([string]$Id, [string]$Source)

    & $winGet.Source install --id $Id --exact --source $Source --silent --disable-interactivity `
        --accept-package-agreements --accept-source-agreements --no-upgrade
    if ($LASTEXITCODE -notin @(0, 0x8A15002B, 0x8A15010D)) {
        throw "WinGet failed for $Id (exit $LASTEXITCODE)."
    }
}

function Install-VerifiedZip {
    param([string]$Url, [string]$Sha256, [string]$ArchiveFolder, [string]$Destination, [string]$EntryPoint)

    if (Test-Path -LiteralPath (Join-Path $Destination $EntryPoint) -PathType Leaf) { return }
    if (Test-Path -LiteralPath $Destination) { throw "Incomplete installation already exists at $Destination." }

    $parent = [IO.Path]::GetFullPath((Split-Path -Parent $Destination))
    $stage = Join-Path $parent ('.freshstart-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    try {
        $zip = Join-Path $stage 'download.zip'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $Sha256) {
            throw "SHA-256 mismatch for $Url."
        }
        $extracted = Join-Path $stage 'extracted'
        Expand-Archive -LiteralPath $zip -DestinationPath $extracted
        $source = Join-Path $extracted $ArchiveFolder
        if (-not (Test-Path -LiteralPath (Join-Path $source $EntryPoint) -PathType Leaf)) {
            throw "Archive is missing $ArchiveFolder\$EntryPoint."
        }
        [IO.Directory]::Move($source, $Destination)
    }
    finally {
        $resolvedStage = (Resolve-Path -LiteralPath $stage).ProviderPath
        $prefix = Join-Path $parent '.freshstart-'
        if ($resolvedStage -eq $stage -and $resolvedStage.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force
        }
    }
}

function Set-JavaHome {
    $temurinRoot = Join-Path $env:ProgramFiles 'Eclipse Adoptium'
    $jdk = Get-ChildItem -LiteralPath $temurinRoot -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\javac.exe') -PathType Leaf } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $jdk) { throw "Temurin JDK 21 was not found under $temurinRoot." }
    $env:JAVA_HOME = $jdk.FullName
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $env:JAVA_HOME, 'User')
    Add-UserPath (Join-Path $env:JAVA_HOME 'bin')
}

function Install-PythonRuntime {
    $aliases = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    $manager = Join-Path $aliases 'pymanager.exe'
    & $manager install --update default
    if ($LASTEXITCODE -ne 0) { throw "Python install manager failed (exit $LASTEXITCODE)." }
    Add-UserPath $aliases
    Add-UserPath (Join-Path $env:LOCALAPPDATA 'Python\bin')
    & (Join-Path $aliases 'python.exe') --version
    if ($LASTEXITCODE -ne 0) { throw "Python version check failed (exit $LASTEXITCODE)." }
}

function Install-Magpie {
    $installDirectory = Join-Path $env:LOCALAPPDATA 'Programs\magpie'
    $app = Join-Path $installDirectory 'magpie.exe'
    if (-not (Test-Path -LiteralPath $app -PathType Leaf)) {
        $architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
        if ($architecture -notin @('AMD64', 'ARM64')) { throw "Magpie does not support Windows architecture $architecture." }
        $assetName = "magpie-windows-$($architecture.ToLowerInvariant()).exe"
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/yetone/magpie-releases/releases/latest'
        $asset = $release.assets | Where-Object name -eq $assetName | Select-Object -First 1
        if (-not $asset -or $asset.digest -notmatch '^sha256:([0-9a-f]{64})$') {
            throw "The latest Magpie release is missing $assetName or its SHA-256 digest."
        }
        $sha256 = $Matches[1]
        $url = "https://github.com/yetone/magpie-releases/releases/download/$($release.tag_name)/$assetName"
        New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
        $stagedApp = Join-Path $installDirectory ("magpie-$([guid]::NewGuid().ToString('N')).download")
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $stagedApp
            if ((Get-FileHash -LiteralPath $stagedApp -Algorithm SHA256).Hash -ne $sha256) {
                throw "SHA-256 mismatch for $assetName."
            }
            [IO.File]::Move($stagedApp, $app)
        }
        finally {
            if (Test-Path -LiteralPath $stagedApp -PathType Leaf) { Remove-Item -LiteralPath $stagedApp -Force }
        }
    }

    $startMenu = [Environment]::GetFolderPath('Programs')
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut((Join-Path $startMenu 'Magpie (yetone).lnk'))
    $shortcut.TargetPath = $app
    $shortcut.WorkingDirectory = $installDirectory
    $shortcut.Save()
}

function Install-LarkCli {
    $npm = Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue
    if ($npm) {
        $npmPath = $npm.Source
    }
    else {
        $nodeDirectory = Join-Path $env:ProgramFiles 'nodejs'
        $npmPath = Join-Path $nodeDirectory 'npm.cmd'
        if (-not (Test-Path -LiteralPath $npmPath -PathType Leaf)) {
            throw 'npm.cmd was not found. Check the Node.js installation.'
        }
        $env:Path = "$nodeDirectory;$env:Path"
    }

    & $npmPath install --global '@larksuite/cli'
    if ($LASTEXITCODE -ne 0) { throw "lark-cli npm installation failed (exit $LASTEXITCODE)." }
    $npmPrefix = & $npmPath prefix --global
    if ($LASTEXITCODE -ne 0 -or -not $npmPrefix) { throw 'Could not find the npm global installation directory.' }
    & (Join-Path $npmPrefix 'lark-cli.cmd') --version
    if ($LASTEXITCODE -ne 0) { throw "lark-cli version check failed (exit $LASTEXITCODE)." }
    Add-UserPath $npmPrefix
}

function Install-Gradle {
    $gradleHome = Join-Path $env:LOCALAPPDATA "Gradle\gradle-$gradleVersion"
    Install-VerifiedZip -Url "https://services.gradle.org/distributions/gradle-$gradleVersion-bin.zip" `
        -Sha256 '971fcd7150ca4ba04852c0b2ca0d2d0ab9468e14b03473eab19528809914c76b' `
        -ArchiveFolder "gradle-$gradleVersion" -Destination $gradleHome -EntryPoint 'bin\gradle.bat'
    & (Join-Path $gradleHome 'bin\gradle.bat') --version
    if ($LASTEXITCODE -ne 0) { throw "Gradle version check failed (exit $LASTEXITCODE)." }
    Add-UserPath (Join-Path $gradleHome 'bin')
}

function Install-AndroidSdk {
    $toolsHome = Join-Path $sdkRoot 'cmdline-tools\latest'
    Install-VerifiedZip -Url "https://dl.google.com/android/repository/$androidTools" `
        -Sha256 '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a' `
        -ArchiveFolder 'cmdline-tools' -Destination $toolsHome -EntryPoint 'bin\sdkmanager.bat'
    $manager = Join-Path $toolsHome 'bin\sdkmanager.bat'
    $rootArgument = "--sdk_root=$sdkRoot"
    if ($AcceptAndroidLicenses) {
        @('y') * 64 | & $manager $rootArgument --licenses
    }
    else {
        & $manager $rootArgument --licenses
    }
    if ($LASTEXITCODE -ne 0) { throw "Android SDK license review failed (exit $LASTEXITCODE)." }
    & $manager $rootArgument --install --channel=0 @androidPackages
    if ($LASTEXITCODE -ne 0) { throw "Android SDK package installation failed (exit $LASTEXITCODE)." }

    foreach ($entryPoint in @('platform-tools\adb.exe', 'platforms\android-36\android.jar', 'build-tools\36.0.0\aapt2.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $sdkRoot $entryPoint) -PathType Leaf)) {
            throw "Android SDK is missing $entryPoint. Check the license and sdkmanager output above."
        }
    }
    [Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdkRoot, 'User')
    $env:ANDROID_HOME = $sdkRoot
    Add-UserPath (Join-Path $toolsHome 'bin')
    Add-UserPath (Join-Path $sdkRoot 'platform-tools')
}

$results = foreach ($name in $selected) {
    Write-Host "`nInstalling $name"
    try {
        if ($packages[$name].Count) {
            Install-WinGetPackage -Id $packages[$name][0] -Source $packages[$name][1] | Out-Host
        }
        switch ($name) {
            Python { Install-PythonRuntime | Out-Host }
            JDK { Set-JavaHome }
            Gradle { Install-Gradle | Out-Host }
            AndroidSDK { Install-AndroidSdk | Out-Host }
            Magpie { Install-Magpie }
            LarkCLI { Install-LarkCli | Out-Host }
        }
        [pscustomobject]@{ Package = $name; Status = 'OK'; Details = '' }
    }
    catch {
        [pscustomobject]@{ Package = $name; Status = 'Failed'; Details = $_.Exception.Message }
    }
}

$results | Format-Table -AutoSize -Wrap | Out-Host
if ($results.Status -contains 'Failed') { exit 1 }
Write-Host 'Setup complete. Reopen your terminal to load the updated environment.'
