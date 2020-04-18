Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
. $PSScriptRoot/Get-EnvironmentVariableNames.ps1
. $PSScriptRoot/Write-FunctionCallLogMessage.ps1
. $PSScriptRoot/Update-SessionEnvironment.ps1

# =============================================================================
# Private
# =============================================================================


function _getPort($port) {
    if ($port -eq $null) { $port = $env:ESPPORT }
    return $port
}
function _getElf($path) {
    if (!$path) { $path = Get-Location }
    else { $path = Resolve-Path $path }
    $proj = IdfProject-GetName($path)
    if ($proj) {
        return [IO.Path]::Combine($path, "build", "$proj.elf")
    }
    return $false
}

function _getBootloaderElf() {
    if (!$path) { $path = Get-Location }
    else { $path = Resolve-Path $path }
    $proj = IdfProject-GetName($path)
    if ($proj) {
        return [IO.Path]::Combine($path, "build", "bootloader", "bootloader.elf")
    }
    return $false
}

function _getIdfPaths($idf_path) {
    if ($IDF_PATH -eq $null) { $IDF_PATH = $env:IDF_PATH }
    if ($idf_path -eq $null) { $idf_path = $IDF_PATH }
    # if ($idf_path -eq $null) { throw "The IDF_PATH is not set" }
    return $idf_path
}

function _getOpenocdScripts($oscripts) {
    if ($OPENOCD_SCRIPTS -eq $null) { $OPENOCD_SCRIPTS = $env:OPENOCD_SCRIPTS }
    if ($oscripts -eq $null) { $oscripts = $OPENOCD_SCRIPTS }
    # if ($target -eq $null) { throw "The IDF_TARGET is not set" }
    return $oscripts
}

function _getIdfPython{
    if ($env:IDF_PYTHON -eq $null) { return $($(Get-Command python).Path) }
    else { return $env:IDF_PYTHON }
}

function ReadNget {
    param(
        [parameter(Mandatory = $true)]
        [String]$Path,

        [parameter(Mandatory = $true)]
        [String]$LinePattern,

        [parameter(Mandatory = $true)]
        [String]$InlinePattern,

        [parameter(Mandatory = $false)]
        [Int32]$Match2Return

    )
    $Path = Resolve-Path $Path -ErrorAction SilentlyContinue
    # if (Test-Path -Path $Path -ErrorAction SilentlyContinue)
    if ($Path) {
        if (!$Match2Return) { $Match2Return = 1 }

        $proj_line = Select-String -Path $Path -Pattern $LinePattern | Select-Object Line

        if ($proj_line -Match $InlinePattern) {
            $m = $Matches
            return $m[$Match2Return]
        }
    }
}


# =============================================================================
# Public
# =============================================================================
function Idf {
    Start-Process -NoNewWindow -Wait -FilePath $(_getIdfPython) -Args "`"${env:IDF_PATH}/tools/idf.py`" $args"
}

function Idf-SetupEnv {
    $cmd = "$(_getIdfPython) $(_getIdfPaths)/tools/idf_tools.py export --format key-value"
    $envars_array = @()
    $envars_raw = $(Invoke-Expression $cmd)
    foreach ($line  in $envars_raw) {
        $pair = $line.split("=") # split in name, val
        $var_name = $pair[0].Trim() # trim spaces on the ends of the name
        $var_val = $pair[1].Trim() # trim spaces on the ends of the val
        if ($var_name -eq "PATH"){
            $var_val = $var_val -replace "%PATH%", "" # remove path
            $var_name = "IDF_BIN_PATHS"
        }
        $var_val = $var_val -replace "%(.+)%", "`$env:`$1" # convert var syntax to PS using RegEx
        $envars_array += (, ($var_name, $var_val))
    }

    foreach ($pair  in $envars_array) {
        # setting the values
        $var_name = $pair[0].Trim() # trim spaces on the ends of the name
        $var_val = $pair[1].Trim() # trim spaces on the ends of the val
        if ($var_val -ne ""){
            [System.Environment]::SetEnvironmentVariable($var_name, $var_val, "User")
        }
    }
    Update-SessionEnvironment
    Idf-Print
    Write-Output "`n[ DONE ]"
}


function Idf-Export {
    Param(
        [parameter(Mandatory = $false)] [String]$Path
    )
    $curr_location = $PWD
    $is_found = $false
    if ($Path) {
        Set-Location $Path
    }

    while (!("$pwd" -eq "$($pwd.drive.name):\")) {
        # while not top path
        if (Test-Path ./export.ps1 -PathType Leaf) {
            $is_found = $true
            break
        }
        else {
            Set-Location ..
            Write-Output " - Checking : $(Get-Location)"
        }
    }

    if (!$is_found){
        Write-Output " - Checking : `$env:IDF_PATH";
        Set-Location $env:IDF_PATH
        if (Test-Path ./export.ps1 -PathType Leaf){
            $is_found = $true
        }
    }

    if ($is_found){
        Write-Output " - Found IDF!"
        . ./export.ps1
    }
    else {
        Write-Output "No IDF with export.ps1 found"
    }
    Set-Location $curr_location
    Write-Output "[ DONE ] Success: "
    return $is_found
}

function IdfProject-GetElf($Path) {
    return _getElf($Path)
}

function Idf-Install {
    Param(
        [parameter(Mandatory = $false)] [String]$path
    )
    $curr_location = $PWD
    $is_found = $false
    if ($path) {
        Set-Location $path
    }

    while (!("$pwd" -eq "$($pwd.drive.name):\")) {
        # while not top path
        if (Test-Path ./install.ps1 -PathType Leaf) {
            $is_found = $true
            break
        }
        else {
            Set-Location ..
            Write-Output " - Checking : $(Get-Location)"
        }
    }

    if (!$is_found){
        Write-Output " - Checking : `$env:IDF_PATH";
        Set-Location $env:IDF_PATH
        if (Test-Path ./install.ps1 -PathType Leaf){
            $is_found = $true
        }
    }

    if ($is_found){
        Write-Output " - Found IDF!"
        ./install.ps1
    }
    else {
        Write-Output "No IDF with install.ps1 found"
    }
    Set-Location $curr_location
    Write-Output "[ DONE ] Success: "
    return $is_found
}

function IdfProject-GetName($path) {
    $val = $false # default value
    $file_name = "CMakeLists.txt"

    if (!$Path) { $Path = Get-Location } ; Push-Location $Path
    $file_path = Join-Path $path $file_name

    $val = ReadNget -Path $file_path -LinePattern "^project[(]" -InlinePattern "project[(](.+)[)]"
    Pop-Location

    return $val
}

function IdfProject-GetTarget($Path){
    $file_name = "sdkconfig"

    if (!$Path) { $Path = Get-Location } ; Push-Location $Path
    $file_path = Join-Path $Path $file_name

    $val = ReadNget -Path $file_path -LinePattern "^CONFIG_IDF_TARGET=" -InlinePattern "`"(.+)`""
    Pop-Location

    if (!$val) {
        Write-Output "Not set. Use `"idf set-target TARGET_NAME`""
    }
    return $val
}

function Idf-Print($Path) {
    $info = @"
IDF info
    - IDF_PATH          $env:IDF_PATH
    - IDF_TOOLS_PATH    $env:IDF_TOOLS_PATH
Project info
    - Name              $(IdfProject-GetName $Path)
    - Target            $(IdfProject-GetTarget $Path)
"@
    Write-Output $info
}
