Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
. $PSScriptRoot/Get-EnvironmentVariableNames.ps1
. $PSScriptRoot/Write-FunctionCallLogMessage.ps1
. $PSScriptRoot/Update-SessionEnvironment.ps1

# =============================================================================
# Private
# =============================================================================


function _getPort($port) {
    if ($ESPPORT -eq $null) { $ESPPORT = $env:ESPPORT }
    if ($port -eq $null) { $port = $ESPPORT }
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
    Start-Process -NoNewWindow -FilePath $(_getIdfPython) -Args "`"${env:IDF_PATH}/tools/idf.py`" $args"
}


function Idf-Print {
    if ($IDF_PATH -eq $null) { $IDF_PATH = $env:IDF_PATH }
    if ($IDF_BIN_PATHS -eq $null) { $IDF_BIN_PATHS = $env:IDF_BIN_PATHS }
    if ($IDF_TARGET -eq $null) { $IDF_TARGET = $env:IDF_TARGET }
    if ($IDF_ELF -eq $null) { $IDF_ELF = $env:IDF_ELF }
    if ($ESPPORT -eq $null) { $ESPPORT = $env:ESPPORT }
    if ($IDF_PYTHON -eq $null) { $IDF_PYTHON = Get-Command "python" }
    if ($OPENOCD_PATH -eq $null) { $OPENOCD_PATH = $env:OPENOCD_PATH }
    if ($OPENOCD_SCRIPTS -eq $null) { $OPENOCD_SCRIPTS = $env:OPENOCD_SCRIPTS }

    Write-Output "`$IDF_PATH        $IDF_PATH"
    Write-Output "`$IDF_TARGET      $IDF_TARGET"
    Write-Output "`$IDF_ELF         $IDF_ELF"
    Write-Output "`$ESPPORT         $ESPPORT"
    # Write-Output "`$IDF_PYTHON      $IDF_PYTHON"
    Write-Output "`$OPENOCD_PATH    $OPENOCD_PATH"
    Write-Output "`$OPENOCD_SCRIPTS $OPENOCD_SCRIPTS"
    # Write-Output "`$Path            $env:Path"
    Write-Output "`$IDF_BIN_PATHS   $IDF_BIN_PATHS"
}

function Idf-SetupEnv {
    $cmd = "$(_getIdfPython) $(_getIdfPaths)/tools/idf_tools.py export --format key-value"
    $envars_array = @()
    $envars_raw = $(Invoke-Expression $cmd)
    foreach ($line  in $envars_raw) {
        $pair = $line.split("=") # split in name, val
        $var_name = $pair[0].Trim() # trim spaces on the ends of the name
        $var_val = $pair[1].Trim() # trim spaces on the ends of the val
        if($var_name -eq "PATH"){
            $var_val = $var_val -replace "%PATH%", "" # remove path
            $var_name = "IDF_BIN_PATHS"
        }
        $var_val = $var_val -replace "%(.+)%", "`$env:`$1" # convert var syntax to PS using RegEx
        $envars_array += (, ($var_name, $var_val))
    }

    foreach ($pair  in $envars_array) # setting the values
    {
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

function Idf-Port($Port) {
    if ($Port -ne $null) {
        Set-Variable -Name "ESPPORT" -Value $Port -Scope "Global"
    }
    else {
        return _getPort
    }
}

function Idf-Target {
    Param(
        [parameter(Mandatory = $false)]
        [ValidateSet("esp32", "esp32s2")]
        [String]$Target
    )
    if ($Target) {
        idf set-target $Target
    }
    else {
        return IdfProject-GetTarget
    }
}

function Idf-Elf($Path) {
    return _getElf($Path)
}


function Idf-Export {
    # TODO handling of the default value with ~/esp/esp-idf
    Param(
        [parameter(Mandatory = $false)] [String]$path,
        [parameter(Mandatory = $false)] [String]$port,
        [parameter(Mandatory = $false)] [String]$elf,
        [parameter(Mandatory = $false)] [ValidateSet("esp32", "esp32s2")] [String]$target,
        [parameter(Mandatory = $false)] [String]$with_cmd,

        [parameter(Mandatory = $false)] [Switch]$Default
    )
    $counter = 16
    if (!$path) {
        if ($(Test-Path -Path Env:IDF_PATH_DEFAULT)) {
            Push-Location $Env:IDF_PATH_DEFAULT
        }
    }
    else {
        Push-Location $path
    }
    while ($counter) {
        $is = Test-Path (Join-Path (Resolve-Path .) "export.ps1") -PathType Leaf
        if ($is -eq $true) {

            Write-Output " - Found IDF!";
            . ./export.ps1
            Pop-Location
            Idf-Port $port
            Idf-Elf $elf
            if ($target) { Idf-Target $target }
            else { Idf-Target }
            if ($with_cmd) { Invoke-Expression -Command "$with_cmd" }
            return
        }
        else {
            Set-Location ..;
            Write-Output " - Checking : $(Get-Location)";
            $counter--;
        }
    }


    Pop-Location
    Write-Output "No exports.ps1 found"

}

function Idf-Install {
    $counter = 16
    Push-Location .
    while ($counter) {
        $is = Test-Path (Join-Path (Resolve-Path .) "install.ps1") -PathType Leaf
        if ($is -eq $true) {
            ./install.ps1
            Pop-Location
            return
        }
        else {
            Set-Location ..;
            Write-Output (Get-Location);
            $counter--;
        }
    }
    Pop-Location
    Write-Output "No esp-idf/install.ps1 found"

}



function IdfProject-GetName($path) {
    $val = $false # default value
    $file_name = "CMakeLists.txt"

    if (!$path) { $path = Get-Location } ; Push-Location $path
    $file_path = Join-Path $path $file_name

    $val = ReadNget -Path $file_path -LinePattern "^project[(]" -InlinePattern "project[(](.+)[)]"
    Pop-Location

    return $val
}

function IdfProject-GetTarget($Path){

    $val = "esp32" # default value
    $file_name = "sdkconfig"

    if (!$path) { $path = Get-Location } ; Push-Location $path
    $file_path = Join-Path $path $file_name

    $val = ReadNget -Path $file_path -LinePattern "^CONFIG_IDF_TARGET=" -InlinePattern "`"(.+)`""
    Pop-Location

    return $val
}
