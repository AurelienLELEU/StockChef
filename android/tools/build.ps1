param([switch]$CoreOnly, [string[]]$Tasks = @(':app:assembleDebug', ':app:lintDebug'))
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path $PSScriptRoot -Parent
$shared = [System.IO.Path]::GetFullPath((Join-Path $root '../../CashDraft/android/.toolchain'))
$tools = if (Test-Path $shared) { $shared } else { Join-Path $root '.toolchain' }
[System.IO.Directory]::CreateDirectory($tools) | Out-Null
if (!$env:JAVA_HOME -or !(Test-Path (Join-Path $env:JAVA_HOME 'bin/java.exe'))) {
    $jdk = Get-ChildItem $tools -Directory -Filter 'jdk-*' | Select-Object -First 1
    if (!$jdk) {
        $metadata = Invoke-RestMethod 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'
        $package = $metadata[0].binary.package
        $archive = Join-Path $tools 'jdk.zip'
        Invoke-WebRequest -UseBasicParsing $package.link -OutFile $archive
        if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $package.checksum) { throw 'JDK invalide.' }
        Expand-Archive $archive $tools -Force
        $jdk = Get-ChildItem $tools -Directory -Filter 'jdk-*' | Select-Object -First 1
    }
    $env:JAVA_HOME = $jdk.FullName
}
$env:GRADLE_USER_HOME = Join-Path $env:LOCALAPPDATA 'CashDraftAndroid/gradle'
$build = Join-Path $env:LOCALAPPDATA 'StockChefAndroid/build'
$gradle = Join-Path $tools 'gradle-8.11.1/bin/gradle.bat'
if (!(Test-Path $gradle) -or !(Test-Path (Join-Path $tools 'gradle-8.11.1/lib/agents/gradle-instrumentation-agent-8.11.1.jar'))) {
    $archive = Join-Path $tools 'gradle.zip'
    if (!(Test-Path $archive)) { Invoke-WebRequest -UseBasicParsing 'https://services.gradle.org/distributions/gradle-8.11.1-bin.zip' -OutFile $archive }
    $checksum = (Invoke-RestMethod 'https://services.gradle.org/distributions/gradle-8.11.1-bin.zip.sha256').Trim()
    if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $checksum) { throw 'Gradle invalide.' }
    Expand-Archive $archive $tools -Force
}
& $gradle -p $root "-PlocalBuildRoot=$build" -PcoreOnly=true :core:test --no-daemon --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Tests StockChef en echec.' }
if (!(Test-Path (Join-Path $root 'gradlew.bat'))) {
    & $gradle -p $root -PcoreOnly=true wrapper --gradle-version 8.11.1 --no-validate-url --no-daemon --console=plain
    if ($LASTEXITCODE -ne 0) { throw 'Wrapper en echec.' }
}
if ($CoreOnly) { return }
$sdk = Join-Path $tools 'android-sdk'
$manager = Join-Path $sdk 'cmdline-tools/latest/bin/sdkmanager.bat'
if (!(Test-Path $manager)) {
    $archive = Join-Path $tools 'android-commandline.zip'
    Invoke-WebRequest -UseBasicParsing 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $archive
    $temporary = Join-Path $tools 'android-commandline'
    Expand-Archive $archive $temporary -Force
    [System.IO.Directory]::CreateDirectory((Join-Path $sdk 'cmdline-tools')) | Out-Null
    Move-Item (Join-Path $temporary 'cmdline-tools') (Join-Path $sdk 'cmdline-tools/latest')
}
$env:ANDROID_HOME = $sdk
if (!(Test-Path (Join-Path $sdk 'platforms/android-36/android.jar')) -or !(Test-Path (Join-Path $sdk 'build-tools/35.0.0/aapt2.exe'))) {
    & $manager --sdk_root=$sdk 'platform-tools' 'platforms;android-36' 'build-tools;35.0.0'
    if ($LASTEXITCODE -ne 0) { throw 'Installation SDK interrompue.' }
}
& $gradle -p $root "-PlocalBuildRoot=$build" @Tasks --no-daemon --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Compilation StockChef en echec.' }
$artifacts = Join-Path $root 'artifacts'
[System.IO.Directory]::CreateDirectory($artifacts) | Out-Null
Get-ChildItem (Join-Path $build 'app/outputs/apk') -Recurse -Filter '*.apk' | ForEach-Object { Copy-Item $_.FullName $artifacts -Force }