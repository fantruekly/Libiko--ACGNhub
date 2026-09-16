# Generate the Android release keystore and android/key.properties.
# The password is typed by you and is never stored in the repo (key.properties is gitignored).
# Keep the generated android/app/upload-keystore.jks and the password safe: losing them
# means you can never publish an update for the same app.
#
# Usage: powershell -ExecutionPolicy Bypass -File tool\gen_keystore.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keystoreRel = 'upload-keystore.jks'
$keystoreAbs = Join-Path $root "android\app\$keystoreRel"
$alias = 'upload'
$dname = 'CN=Libiko, OU=Libiko, O=Libiko, L=Unknown, ST=Unknown, C=CN'

if (Test-Path $keystoreAbs) {
  throw "keystore already exists: $keystoreAbs (delete it first if you really want to regenerate)"
}

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
  $candidates = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    'C:\Program Files\Java\*\bin\keytool.exe',
    'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
  )
  foreach ($c in $candidates) {
    $found = Get-ChildItem $c -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $keytool = $found.FullName; break }
  }
}
if (-not $keytool) { throw 'keytool not found; install a JDK or Android Studio' }

$secure = Read-Host -AsSecureString "Enter a password for the keystore (you must remember it)"
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
if ([string]::IsNullOrWhiteSpace($plain)) { throw 'password must not be empty' }

& $keytool -genkeypair -v -keystore $keystoreAbs -storetype JKS -keyalg RSA -keysize 2048 `
  -validity 10000 -alias $alias -storepass $plain -keypass $plain -dname $dname
if ($LASTEXITCODE -ne 0) { throw 'keytool failed' }

@"
storePassword=$plain
keyPassword=$plain
keyAlias=$alias
storeFile=$keystoreRel
"@ | Set-Content -Path 'android\key.properties' -Encoding ASCII

Write-Output "keystore:      $keystoreAbs"
Write-Output "key.properties: $root\android\key.properties"
Write-Output 'Back these up (and remember the password); they are gitignored.'
