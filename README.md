# idf-ext

<img src="logo.png" width="250">

Powershell module extending capabilities of ESP-IDF framework and simplifying work with it

[@PowershellGallery](https://www.powershellgallery.com/packages/idf-ext)

## Instalation

In powershell:

```powershell
Install-Module -Name idf-ext
```

## Functions

### Idf

A wrapper around `idf.py`. You can use it freely instead of `idf.py`

### Idf-Export

Arguments:

- Path - path to export. Non-mandatory. If not set the current working directory is used

Dot-sourcing `export.ps1`. If the path is not containing `export.ps1`, checks the upper level. If reaches the top (e.g. `C:\`) checks `$env:IDF_PATH`.

Typical usecase:
```powershell
  C:\Users\dongr\Desktop\blink
> Idf-Export
 - Checking : C:\Users\dongr\Desktop
 - Checking : C:\Users\dongr
 - Checking : C:\Users
 - Checking : C:\
 - Checking : $env:IDF_PATH
 - Found IDF!
...
...
...
Done! You can now compile ESP-IDF projects.
Go to the project directory and run:
    idf.py build


[ DONE ] Success:
True

  C:\Users\dongr\Desktop\blink
>
```


### Idf-Install

Arguments:

- Path - path to export. Non-mandatory. If not set the current working directory is used

Runs `install.ps1` using search logic like at Idf-Export

Typical usecase:
```powershell
  C:\Users\dongr\Desktop\blink
> Idf-Install
 - Checking : C:\Users\dongr\Desktop
 - Checking : C:\Users\dongr
 - Checking : C:\Users
 - Checking : C:\
 - Checking : $env:IDF_PATH
 - Found IDF!
Installing ESP-IDF tools
...
...
...
All done! You can now run:
    export.ps1

[ DONE ] Success:
True

  C:\Users\dongr\Desktop\blink
>
```

### IdfProject-GetName

Arguments:

- Path - path to export. Non-mandatory. If not set the current working directory is used

Return the project name parsing `CMakeLists.txt`

### IdfProject-GetTarget

Arguments:

- Path - path to export. Non-mandatory. If not set the current working directory is used

Return the project's target parsing `sdkconfig`

### IdfProject-CleanComplete

Arguments:

- Path - path to export. Non-mandatory. If not set the current working directory is used

Removes `./build` directory, `sdkconfig`, `sdkconfig.old`

### Idf-SetupEnv

Place all IDF variable to your system environment (to the user scope) permanently. Instead of adding to `PATH` creates `IDF_BIN_PATHS` that you can append manually

Uses `idf_tools.py export` to generate the list of variables

### Idf-Print

Arguments:

- Path - path to export. Non-mandatory. If not set the current working directory is used

Prints a summary information:

```powershell
IDF info
    - IDF_PATH          C:\Users\dongr\.espressif\esp-idf
    - IDF_TOOLS_PATH    C:\Users\dongr\.espressif
Project info
    - Name                blink
    - Target              Not set. Use "idf set-target TARGET_NAME"
```

## License

This work is licensed under the terms of the MIT license.

For a copy, see: [LICENSE](LICENSE)

- site:    https://agramakov.me
- e-mail:  mail@agramakov.me

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://paypal.me/4ndr/1eur)