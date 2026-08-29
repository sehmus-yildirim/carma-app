[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$script:checkCount = 0

function Assert-ReleaseCheck {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw "FAIL: $Message"
    }

    $script:checkCount++
    Write-Host "PASS: $Message"
}

function Read-Plist {
    param([Parameter(Mandatory = $true)][string]$Path)

    [xml]$document = Get-Content -LiteralPath $Path -Raw
    return ,$document
}

function Get-PlistNode {
    param(
        [Parameter(Mandatory = $true)]$Document,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $dict = $Document.DocumentElement.SelectSingleNode('dict')
    foreach ($keyNode in $dict.SelectNodes('key')) {
        if ($keyNode.InnerText -ne $Key) {
            continue
        }

        $valueNode = $keyNode.NextSibling
        while ($null -ne $valueNode -and $valueNode.NodeType -ne [System.Xml.XmlNodeType]::Element) {
            $valueNode = $valueNode.NextSibling
        }
        return $valueNode
    }

    return $null
}

function Get-PlistString {
    param(
        [Parameter(Mandatory = $true)]$Document,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $node = Get-PlistNode -Document $Document -Key $Key
    if ($null -eq $node -or $node.Name -ne 'string') {
        return $null
    }
    return $node.InnerText
}

function Get-PlistArrayStrings {
    param(
        [Parameter(Mandatory = $true)]$Document,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $node = Get-PlistNode -Document $Document -Key $Key
    if ($null -eq $node -or $node.Name -ne 'array') {
        return @()
    }
    return @($node.SelectNodes('string') | ForEach-Object { $_.InnerText })
}

function Resolve-PathFromRepo {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $repoRoot $RelativePath
}

$infoPath = Resolve-PathFromRepo 'ios\Runner\Info.plist'
$entitlementsPath = Resolve-PathFromRepo 'ios\Runner\Runner.entitlements'
$googlePath = Resolve-PathFromRepo 'ios\Runner\GoogleService-Info.plist'
$projectPath = Resolve-PathFromRepo 'ios\Runner.xcodeproj\project.pbxproj'
$podfilePath = Resolve-PathFromRepo 'ios\Podfile'
$frameworkInfoPath = Resolve-PathFromRepo 'ios\Flutter\AppFrameworkInfo.plist'
$firebaseOptionsPath = Resolve-PathFromRepo 'lib\firebase_options.dart'
$appDelegatePath = Resolve-PathFromRepo 'ios\Runner\AppDelegate.swift'
$sceneDelegatePath = Resolve-PathFromRepo 'ios\Runner\SceneDelegate.swift'
$iconCatalogPath = Resolve-PathFromRepo 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Contents.json'

$requiredFiles = @(
    $infoPath,
    $entitlementsPath,
    $googlePath,
    $projectPath,
    $podfilePath,
    $frameworkInfoPath,
    $firebaseOptionsPath,
    $appDelegatePath,
    $sceneDelegatePath,
    $iconCatalogPath
)
foreach ($file in $requiredFiles) {
    Assert-ReleaseCheck (Test-Path -LiteralPath $file -PathType Leaf) "Datei vorhanden: $($file.Substring($repoRoot.Length + 1))"
}

$info = Read-Plist $infoPath
$entitlements = Read-Plist $entitlementsPath
$google = Read-Plist $googlePath
$frameworkInfo = Read-Plist $frameworkInfoPath
$project = Get-Content -LiteralPath $projectPath -Raw
$podfile = Get-Content -LiteralPath $podfilePath -Raw
$firebaseOptions = Get-Content -LiteralPath $firebaseOptionsPath -Raw
$appDelegate = Get-Content -LiteralPath $appDelegatePath -Raw
$sceneDelegate = Get-Content -LiteralPath $sceneDelegatePath -Raw

Assert-ReleaseCheck ((Get-PlistString $info 'CFBundleDisplayName') -eq 'plaqa') 'Sichtbarer iOS-App-Name ist plaqa'
Assert-ReleaseCheck ((Get-PlistString $info 'CFBundleIdentifier') -eq '$(PRODUCT_BUNDLE_IDENTIFIER)') 'Info.plist verwendet die Xcode-Bundle-ID'
Assert-ReleaseCheck ($project -match 'PRODUCT_BUNDLE_IDENTIFIER = de\.plaqa\.app;') 'Runner-Bundle-ID ist de.plaqa.app'
Assert-ReleaseCheck ($project -match 'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;') 'Runner verwendet die gepruefte Entitlements-Datei'
Assert-ReleaseCheck (($project | Select-String -Pattern 'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;' -AllMatches).Matches.Count -ge 3) 'Xcode-Konfigurationen verwenden iOS 15.0'
Assert-ReleaseCheck ($podfile -match "platform :ios, '15\.0'") 'CocoaPods verwendet iOS 15.0'
Assert-ReleaseCheck ((Get-PlistString $frameworkInfo 'MinimumOSVersion') -eq '15.0') 'Flutter-Framework verwendet iOS 15.0'

$usageKeys = @(
    'NSCameraUsageDescription',
    'NSLocationWhenInUseUsageDescription',
    'NSMicrophoneUsageDescription',
    'NSPhotoLibraryUsageDescription',
    'NSPhotoLibraryAddUsageDescription'
)
foreach ($key in $usageKeys) {
    $description = Get-PlistString $info $key
    Assert-ReleaseCheck (-not [string]::IsNullOrWhiteSpace($description)) "Datenschutzhinweis vorhanden: $key"
}

$backgroundModes = Get-PlistArrayStrings $info 'UIBackgroundModes'
Assert-ReleaseCheck ($backgroundModes -contains 'fetch') 'Background fetch ist aktiviert'
Assert-ReleaseCheck ($backgroundModes -contains 'remote-notification') 'Remote notifications sind aktiviert'
$proxyNode = Get-PlistNode $info 'FirebaseAppDelegateProxyEnabled'
Assert-ReleaseCheck ($null -eq $proxyNode -or $proxyNode.Name -ne 'false') 'Firebase Method Swizzling ist nicht deaktiviert'

Assert-ReleaseCheck ((Get-PlistString $entitlements 'aps-environment') -eq 'development') 'APNs-Entitlement ist fuer lokale Signierung vorhanden'
Assert-ReleaseCheck ((Get-PlistString $entitlements 'com.apple.developer.devicecheck.appattest-environment') -eq 'production') 'App-Attest-Entitlement verwendet den Firebase-kompatiblen Produktionsmodus'
$appleSignIn = Get-PlistArrayStrings $entitlements 'com.apple.developer.applesignin'
Assert-ReleaseCheck ($appleSignIn -contains 'Default') 'Sign in with Apple ist im Entitlement aktiviert'
Assert-ReleaseCheck ($project -match 'com\.apple\.BackgroundModes = \{\s*enabled = 1;') 'Xcode markiert Background Modes als Capability'
Assert-ReleaseCheck ($project -match 'com\.apple\.Push = \{\s*enabled = 1;') 'Xcode markiert Push Notifications als Capability'
Assert-ReleaseCheck ($project -match 'com\.apple\.SignInWithApple = \{\s*enabled = 1;') 'Xcode markiert Sign in with Apple als Capability'

$bundleId = Get-PlistString $google 'BUNDLE_ID'
$projectId = Get-PlistString $google 'PROJECT_ID'
$senderId = Get-PlistString $google 'GCM_SENDER_ID'
$appId = Get-PlistString $google 'GOOGLE_APP_ID'
$clientId = Get-PlistString $google 'CLIENT_ID'
$reversedClientId = Get-PlistString $google 'REVERSED_CLIENT_ID'
Assert-ReleaseCheck ($bundleId -eq 'de.plaqa.app') 'Firebase-iOS-Bundle-ID stimmt'
Assert-ReleaseCheck ($projectId -eq 'carma-a84e4') 'Firebase-Projekt-ID stimmt'
Assert-ReleaseCheck ($firebaseOptions.Contains("appId: '$appId'")) 'FlutterFire-App-ID stimmt mit GoogleService-Info.plist ueberein'
Assert-ReleaseCheck ($firebaseOptions.Contains("messagingSenderId: '$senderId'")) 'FlutterFire-Sender-ID stimmt ueberein'
Assert-ReleaseCheck ($firebaseOptions.Contains("projectId: '$projectId'")) 'FlutterFire-Projekt-ID stimmt ueberein'
Assert-ReleaseCheck ($firebaseOptions.Contains("'$clientId'")) 'FlutterFire-iOS-Client-ID stimmt ueberein'
Assert-ReleaseCheck ($firebaseOptions.Contains("iosBundleId: '$bundleId'")) 'FlutterFire-iOS-Bundle-ID stimmt ueberein'
Assert-ReleaseCheck ($info.OuterXml.Contains($reversedClientId)) 'Google-URL-Scheme stimmt mit Firebase ueberein'
Assert-ReleaseCheck ($project -match 'GoogleService-Info\.plist in Resources') 'GoogleService-Info.plist ist Runner-Ressource'

Assert-ReleaseCheck ($appDelegate -match 'class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate') 'AppDelegate verwendet den aktuellen impliziten Flutter-Engine-Lifecycle'
Assert-ReleaseCheck ($appDelegate -match 'GeneratedPluginRegistrant\.register') 'Flutter-Plugins werden nativ registriert'
Assert-ReleaseCheck ($sceneDelegate -match 'class SceneDelegate: FlutterSceneDelegate') 'SceneDelegate verwendet FlutterSceneDelegate'
Assert-ReleaseCheck ($podfile -match "target 'Runner' do") 'Podfile enthaelt das Runner-Target'
Assert-ReleaseCheck ($podfile -match "target 'RunnerTests' do") 'Podfile enthaelt das RunnerTests-Target'

$iconCatalog = Get-Content -LiteralPath $iconCatalogPath -Raw | ConvertFrom-Json
$iconDirectory = Split-Path -Parent $iconCatalogPath
Assert-ReleaseCheck ($iconCatalog.images.Count -eq 19) 'App-Icon-Katalog enthaelt alle 19 iPhone-, iPad- und Store-Slots'
Add-Type -AssemblyName System.Drawing
foreach ($entry in $iconCatalog.images) {
    Assert-ReleaseCheck (-not [string]::IsNullOrWhiteSpace($entry.filename)) "Icon-Dateiname gesetzt: $($entry.idiom) $($entry.size) $($entry.scale)"
    $iconPath = Join-Path $iconDirectory $entry.filename
    Assert-ReleaseCheck (Test-Path -LiteralPath $iconPath -PathType Leaf) "Icon vorhanden: $($entry.filename)"

    $logicalSize = [double](($entry.size -split 'x')[0])
    $scale = [double](($entry.scale -replace 'x', ''))
    $expectedPixels = [int][Math]::Round($logicalSize * $scale)
    $image = [System.Drawing.Image]::FromFile($iconPath)
    try {
        Assert-ReleaseCheck ($image.Width -eq $expectedPixels -and $image.Height -eq $expectedPixels) "Icon-Abmessung stimmt: $($entry.filename)"
        Assert-ReleaseCheck (-not [System.Drawing.Image]::IsAlphaPixelFormat($image.PixelFormat)) "Icon besitzt keinen Alpha-Kanal: $($entry.filename)"
    }
    finally {
        $image.Dispose()
    }
}

$forbiddenSigningFiles = @(Get-ChildItem -LiteralPath (Resolve-PathFromRepo 'ios') -Recurse -File | Where-Object {
    $_.Extension -in @('.p8', '.p12', '.mobileprovision', '.cer', '.key', '.pem')
})
Assert-ReleaseCheck ($forbiddenSigningFiles.Count -eq 0) 'Keine privaten Apple-Signierdateien liegen im iOS-Projekt'
Assert-ReleaseCheck ($project -notmatch 'DEVELOPMENT_TEAM = [A-Z0-9]+;') 'Kein fremdes Apple-Team ist fest im Projekt verdrahtet'

Write-Host "iOS Windows release configuration: $script:checkCount checks passed."
