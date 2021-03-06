Function Get-DotFiles {
    <#
        .SYNOPSIS
        Enumerates dotfiles components
        .DESCRIPTION
        Enumerates the available dotfiles components, where each component is represented by a top-level folder in the folder specified by the $DotFilesPath variable or the -Path parameter.

        For each component a Component object is constructed and returned which contains the component's basic details, availability, installation state, and other configuration settings.
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.
        .EXAMPLE
        PS C:\>Get-DotFiles

        Enumerates all available dotfiles components and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>Get-DotFiles -Autodetect

        Enumerates all available dotfiles components, attempting automatic detection of those that lack a metadata file, and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>$DotFiles = Get-DotFiles

        Enumerates all available dotfiles components and saves the returned collection of Component objects to the $DotFiles variable. This allows easy inspection and custom formatting of the Component objects.
        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
    )

    Initialize-PSDotFiles @PSBoundParameters

    $Components = @()
    $Directories = Get-ChildItem $script:DotFilesPath -Directory

    foreach ($Directory in $Directories) {
        $Component = Get-DotFilesComponent -Directory $Directory

        if ($Component.Availability -in ('Available', 'AlwaysInstall')) {
            $Results = Install-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath -TestOnly -Silent
            $Component.State = Get-ComponentInstallResult $Results
        }

        $Components += $Component
    }

    return $Components
}

Function Install-DotFiles {
    <#
        .SYNOPSIS
        Installs dotfiles components
        .DESCRIPTION
        Installs all available dotfiles components, or the nominated subset provided via a collection of Component objects as previously returned by the Get-DotFiles cmdlet.

        For each installed component a Component object is returned which contains the component's basic details, availability, installation state, and other configuration settings.
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This parameter is only used when not providing a collection of Component objects as the input, as in this case, the path of each Component is already provided in the object.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This parameter is only used when not providing a collection of Component objects as the input, as in this case, the availability of each Component is already provided in the object.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.
        .PARAMETER Components
        A collection of Component objects to be installed as previously returned by Get-DotFiles. The collection may be a filtered set of Components to ensure only a desired subset is installed.

        Note that only the Component objects with an appropriate Availability state will be installed.
        .EXAMPLE
        PS C:\>Install-DotFiles

        Installs all available dotfiles components and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>Install-DotFiles -Autodetect

        Installs all available dotfiles components, attempting automatic detection of those that lack a metadata file, and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>$Components = Get-DotFiles | ? { $_.Name -eq 'git' -or $_.Name -eq 'vim' }
        PS C:\>Install-DotFiles -Components $Components

        Installs only the 'git' and 'vim' dotfiles components, as provided by a filtered set of the components returned by Get-DotFiles, and stored in the $Components variable.
        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [CmdletBinding(DefaultParameterSetName='Retrieve',SupportsShouldProcess=$true,ConfirmImpact='Low')]
    Param(
        [Parameter(ParameterSetName='Retrieve',Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(ParameterSetName='Retrieve',Mandatory=$false)]
            [Switch]$Autodetect,
        [Parameter(ParameterSetName='Provided',Position=0,Mandatory=$false)]
            [Component[]]$Components
    )

    if (!(Test-IsAdministrator)) {
        if ($PSBoundParameters.ContainsKey('WhatIf')) {
            Write-Warning "Not running with Administrator privileges but ignoring due to -WhatIf."
        } else {
            throw "Unable to run Install-DotFiles as not running with Administrator privileges."
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'Retrieve') {
        $Components = Get-DotFiles @PSBoundParameters | ? { $_.Availability -in ('Available', 'AlwaysInstall') }
    } else {
        $UnfilteredComponents = $Components
        $Components = $UnfilteredComponents | ? { $_.Availability -in ('Available', 'AlwaysInstall') }
    }

    foreach ($Component in $Components) {
        $Name = $Component.Name

        if ($PSCmdlet.ShouldProcess($Name, 'Install-DotFilesComponent')) {
            Write-Verbose ("[$Name] Installing...")
        } else {
            Write-Verbose ("[$Name] Simulating install...")
            $Simulate = $true
        }

        Write-Debug ("[$Name] Source directory is: " + $Component.SourcePath)
        Write-Debug ("[$Name] Installation path is: " + $Component.InstallPath)

        if (!$Simulate) {
            $Results = Install-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath
        } else {
            $Results = Install-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath -TestOnly
        }

        $Component.State = Get-ComponentInstallResult $Results
    }

    return $Components
}

Function Remove-DotFiles {
    <#
        .SYNOPSIS
        Removes dotfiles components
        .DESCRIPTION
        Removes all installed dotfiles components, or the nominated subset provided via a collection of Component objects as previously returned by the Get-DotFiles cmdlet.

        For each removed component a Component object is returned which contains the component's basic details, availability, installation state, and other configuration settings.
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This parameter is only used when not providing a collection of Component objects as the input, as in this case, the path of each Component is already provided in the object.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This parameter is only used when not providing a collection of Component objects as the input, as in this case, the availability of each Component is already provided in the object.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.
        .PARAMETER Components
        A collection of Component objects to be removed as previously returned by Get-DotFiles. The collection may be a filtered set of Components to ensure only a desired subset is removed.

        Note that only the Component objects with an appropriate Installed state will be removed.
        .EXAMPLE
        PS C:\>Remove-DotFiles

        Removes all installed dotfiles components and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>Remove-DotFiles -Autodetect

        Removes all available dotfiles components, attempting automatic detection of those that lack a metadata file, and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>$Components = Get-DotFiles | ? { $_.Name -eq 'git' -or $_.Name -eq 'vim' }
        PS C:\>Remove-DotFiles -Components $Components

        Removes only the 'git' and 'vim' dotfiles components, as provided by a filtered set of the components returned by Get-DotFiles, and stored in the $Components variable.
        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [CmdletBinding(DefaultParameterSetName='Retrieve',SupportsShouldProcess=$true,ConfirmImpact='Low')]
    Param(
        [Parameter(ParameterSetName='Retrieve',Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(ParameterSetName='Retrieve',Mandatory=$false)]
            [Switch]$Autodetect,
        [Parameter(ParameterSetName='Provided',Position=0,Mandatory=$false)]
            [Component[]]$Components
    )

    if ($PSCmdlet.ParameterSetName -eq 'Retrieve') {
        $Components = Get-DotFiles @PSBoundParameters | ? { $_.State -in ('Installed', 'PartialInstall') }
    } else {
        $UnfilteredComponents = $Components
        $Components = $UnfilteredComponents | ? { $_.State -in ('Installed', 'PartialInstall') }
    }

    foreach ($Component in $Components) {
        $Name = $Component.Name

        if ($PSCmdlet.ShouldProcess($Name, 'Remove-DotFilesComponent')) {
            Write-Verbose ("[$Name] Removing...")
        } else {
            Write-Verbose ("[$Name] Simulating removal...")
            $Simulate = $true
        }

        Write-Debug ("[$Name] Source directory is: " + $Component.SourcePath)
        Write-Debug ("[$Name] Installation path is: " + $Component.InstallPath)

        if (!$Simulate) {
            $Results = Remove-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath
        } else {
            $Results = Remove-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath -TestOnly
        }

        $Component.State = Get-ComponentInstallResult $Results -Removal
    }

    return $Components
}

Function Initialize-PSDotFiles {
    # This function is intentionally *not* an advanced function so that unknown
    # parameters passed into it via @PSBoundParameters won't cause it to fail.
    # Do not insert a CmdletBinding() or any Parameter[] attributes or it will
    # be designated an advanced function (implicitly in the latter case). The
    # only alternative is to explicitly define all possible parameters which
    # could be passed into this function via @PSBoundParameters, most of which
    # won't ever actually be used here.
    Param(
        [Switch]$Autodetect,
        [String]$Path
    )

    if ($Path) {
        $script:DotFilesPath = Test-DotFilesPath $Path
        if (!$script:DotFilesPath) {
            throw "The provided dotfiles path is either not a directory or it can't be accessed."
        }
    } elseif ($global:DotFilesPath) {
        $script:DotFilesPath = Test-DotFilesPath $global:DotFilesPath
        if (!$script:DotFilesPath) {
            throw "The default dotfiles path (`$DotFilesPath) is either not a directory or it can't be accessed."
        }
    } else {
        throw "No dotfiles path was provided and the default dotfiles path (`$DotFilesPath) has not been configured."
    }
    Write-Verbose "Using dotfiles directory: $script:DotFilesPath"

    $script:GlobalMetadataPath = Join-Path $PSScriptRoot 'metadata'
    Write-Debug "Using global metadata directory: $script:GlobalMetadataPath"

    $script:DotFilesMetadataPath = Join-Path $script:DotFilesPath 'metadata'
    Write-Debug "Using dotfiles metadata directory: $script:DotFilesMetadataPath"

    if ($PSBoundParameters.ContainsKey('Autodetect')) {
        $script:DotFilesAutodetect = $Autodetect
    } elseif (Get-Variable -Name DotFilesAutodetect -Scope Global -ErrorAction SilentlyContinue | Out-Null) {
        $script:DotFilesAutodetect = $global:DotFilesAutodetect
    } else {
        $script:DotFilesAutodetect = $false
    }
    Write-Debug "Automatic component detection state: $script:DotFilesAutodetect"

    Write-Debug "Refreshing cache of installed programs..."
    $script:InstalledPrograms = Get-InstalledPrograms
}

Function Find-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Name,
        [Parameter(Mandatory=$false)]
            [String]$Pattern = "*$Name*",
        [Parameter(Mandatory=$false)]
            [Switch]$CaseSensitive,
        [Parameter(Mandatory=$false)]
            [Switch]$RegularExpression
    )

    $MatchingParameters = @{'Property'='DisplayName';
                            'Value'=$Pattern}
    if (!$CaseSensitive -and !$RegularExpression) {
        $MatchingParameters += @{'ILike'=$true}
    } elseif (!$CaseSensitive -and $RegularExpression) {
        $MatchingParameters += @{'IMatch'=$true}
    } elseif ($CaseSensitive -and !$RegularExpression) {
        $MatchingParameters += @{'CLike'=$true}
    } else {
        $MatchingParameters += @{'CMatch'=$true}
    }

    $MatchingPrograms = $script:InstalledPrograms | Where-Object @MatchingParameters
    if ($MatchingPrograms) {
        return $MatchingPrograms
    }
    return $false
}

Function Get-ComponentInstallResult {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
            [Boolean[]]$Results,
        [Parameter(Mandatory=$false)]
            [Switch]$Removal
    )

    if ($Results) {
        $TotalResults = ($Results | measure).Count
        $SuccessCount = ($Results | ? { $_ -eq $true  } | measure).Count
        $FailureCount = ($Results | ? { $_ -eq $false } | measure).Count

        if ($SuccessCount -eq $TotalResults) {
            if (!$Removal) {
                return [InstallState]::Installed
            } else {
                return [InstallState]::NotInstalled
            }
        } elseif ($FailureCount -eq $TotalResults) {
            if (!$Removal) {
                return [InstallState]::NotInstalled
            } else {
                return [InstallState]::Installed
            }
        } else {
            return [InstallState]::PartialInstall
        }
    }
    return [InstallState]::Unknown
}

Function Get-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.IO.DirectoryInfo]$Directory
    )

    $Name               = $Directory.Name
    $MetadataFile       = $Name + '.xml'
    $GlobalMetadataFile = Join-Path $script:GlobalMetadataPath $MetadataFile
    $CustomMetadataFile = Join-Path $script:DotFilesMetadataPath $MetadataFile

    $GlobalMetadataPresent = Test-Path $GlobalMetadataFile -PathType Leaf
    $CustomMetadataPresent = Test-Path $CustomMetadataFile -PathType Leaf

    if ($GlobalMetadataPresent -or $CustomMetadataPresent) {
        if ($GlobalMetadataPresent) {
            Write-Debug "[$Name] Loading global metadata for component..."
            $Metadata = [Xml](Get-Content $GlobalMetadataFile)
            $Component = Initialize-DotFilesComponent -Name $Name -Metadata $Metadata
        }

        if ($CustomMetadataPresent) {
            $Metadata = [Xml](Get-Content $CustomMetadataFile)
            if ($GlobalMetadataPresent) {
                Write-Debug "[$Name] Loading custom metadata overrides for component..."
                $Component = Initialize-DotFilesComponent -Component $Component -Metadata $Metadata
            } else {
                Write-Debug "[$Name] Loading custom metadata for component..."
                $Component = Initialize-DotFilesComponent -Name $Name -Metadata $Metadata
            }
        }
    } elseif ($script:DotFilesAutodetect) {
        Write-Debug "[$Name] Running automatic detection for component..."
        $Component = Initialize-DotFilesComponent -Name $Name
    } else {
        Write-Debug "[$Name] No metadata & automatic detection disabled."
        $Component = [Component]::new($Name, $script:DotFilesPath)
        $Component.Availability = [Availability]::NoLogic
    }

    $Component.PSObject.TypeNames.Insert(0, 'PSDotFiles.Component')
    return $Component
}

Function Get-InstalledPrograms {
    [CmdletBinding()]
    Param()

    $NativeRegPath = '\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $Wow6432RegPath = '\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    $InstalledPrograms = @(
        # Native applications installed system wide
        if (Test-Path "HKLM:$NativeRegPath") { Get-ChildItem "HKLM:$NativeRegPath" }
        # Native applications installed under the current user
        if (Test-Path "HKCU:$NativeRegPath") { Get-ChildItem "HKCU:$NativeRegPath" }
        # 32-bit applications installed system wide on 64-bit Windows
        if (Test-Path "HKLM:$Wow6432RegPath") { Get-ChildItem "HKLM:$Wow6432RegPath" }
        # 32-bit applications installed under the current user on 64-bit Windows
        if (Test-Path "HKCU:$Wow6432RegPath") { Get-ChildItem "HKCU:$Wow6432RegPath" }
    ) | # Get the properties of each uninstall key
        % { Get-ItemProperty $_.PSPath } |
        # Filter out all the uninteresting entries
        ? { $_.DisplayName -and
           !$_.SystemComponent -and
           !$_.ReleaseType -and
           !$_.ParentKeyName -and
           ($_.UninstallString -or $_.NoRemove) }

    Write-Debug ("Registry scan found " + ($InstalledPrograms | measure).Count + " installed programs.")

    return $InstalledPrograms
}

Function Get-SymlinkTarget {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.IO.FileSystemInfo]$Symlink
    )

    if ($Symlink.LinkType -ne 'SymbolicLink') {
        return $false
    }

    $Absolute = [System.IO.Path]::IsPathRooted($Symlink.Target[0])
    if ($Absolute) {
        return $Symlink.Target[0]
    } else {
        return (Resolve-Path (Join-Path (Split-Path $Symlink -Parent) $Symlink.Target[0])).Path
    }
}

Function Initialize-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='New',Mandatory=$true)]
            [String]$Name,
        [Parameter(ParameterSetName='Override',Mandatory=$true)]
            [Component]$Component,
        [Parameter(ParameterSetName='New',Mandatory=$false)]
        [Parameter(ParameterSetName='Override',Mandatory=$true)]
            [Xml]$Metadata
    )

    if ($PSCmdlet.ParameterSetName -eq 'New') {
        $Component = [Component]::new($Name, $script:DotFilesPath)
    } else {
        $Name = $Component.Name
    }

    # Minimal check for sane XML file
    if ($PSBoundParameters.ContainsKey('Metadata')) {
        if (!$Metadata.Component) {
            $Component.Availability = [Availability]::DetectionFailure
            Write-Error "[$Name] No <Component> element in metadata file."
            return $Component
        }
    }

    # Set the friendly name if provided
    if ($Metadata.Component.FriendlyName) {
        $Component.FriendlyName = $Metadata.Component.Friendlyname
    }

    # Configure and perform component detection
    if ($Metadata.Component.Detection.Method -eq 'Automatic' -or
        ($PSCmdlet.ParameterSetName -eq 'New' -and !$Metadata.Component.Detection.Method)) {
        $Parameters = @{'Name'=$Name}

        if (!$Metadata.Component.Detection.MatchRegEx -or
             $Metadata.Component.Detection.MatchRegEx -eq 'False') {
            $Parameters += @{'RegularExpression'=$false}
        } elseif ($Metadata.Component.Detection.MatchRegEx -eq 'True') {
            $Parameters += @{'RegularExpression'=$true}
        } else {
            Write-Error ("[$Name] Invalid MatchRegEx setting for automatic component detection: " + $Metadata.Component.Detection.MatchRegEx)
        }

        if (!$Metadata.Component.Detection.MatchCase -or
             $Metadata.Component.Detection.MatchCase -eq 'False') {
            $Parameters += @{'CaseSensitive'=$false}
        } elseif ($Metadata.Component.Detection.MatchCase -eq 'True') {
            $Parameters += @{'CaseSensitive'=$true}
        } else {
            Write-Error ("[$Name] Invalid MatchCase setting for automatic component detection: " + $Metadata.Component.Detection.MatchCase)
        }

        if ($Metadata.Component.Detection.MatchPattern) {
            $MatchPattern = $Metadata.Component.Detection.MatchPattern
            $Parameters += @{'Pattern'=$MatchPattern}
        }

        $MatchingPrograms = Find-DotFilesComponent @Parameters
        if ($MatchingPrograms) {
            $NumMatchingPrograms = ($MatchingPrograms | measure).Count
            if ($NumMatchingPrograms -eq 1) {
                $Component.Availability = [Availability]::Available
                $Component.UninstallKey = $MatchingPrograms.PSPath
                if (!$Component.FriendlyName -and
                     $MatchingPrograms.DisplayName) {
                    $Component.FriendlyName = $MatchingPrograms.DisplayName
                }
            } elseif ($NumMatchingPrograms -gt 1) {
                Write-Error "[$Name] Automatic detection found $NumMatchingPrograms matching programs."
            }
        } else {
            $Component.Availability = [Availability]::Unavailable
        }
    } elseif ($Metadata.Component.Detection.Method -eq 'FindInPath') {
        if ($Metadata.Component.Detection.FindInPath) {
            $FindBinary = $Metadata.Component.Detection.FindInPath
        } else {
            $FindBinary = $Component.Name
        }

        if (Get-Command $FindBinary -ErrorAction SilentlyContinue) {
            $Component.Availability = [Availability]::Available
        } else {
            $Component.Availability = [Availability]::Unavailable
        }
    } elseif ($Metadata.Component.Detection.Method -eq 'PathExists') {
        if ($Metadata.Component.Detection.PathExists) {
            if (Test-Path $Metadata.Component.Detection.PathExists) {
                $Component.Availability = [Availability]::Available
            } else {
                $Component.Availability = [Availability]::Unavailable
            }
        } else {
            Write-Error "[$Name] No absolute path specified for testing component availability."
        }
    } elseif ($Metadata.Component.Detection.Method -eq 'Static') {
        if ($Metadata.Component.Detection.Availability) {
            $Availability = $Metadata.Component.Detection.Availability
            $Component.Availability = [Availability]::$Availability
        } else {
            Write-Error "[$Name] No component availability state specified for static detection."
        }
    } elseif ($Metadata.Component.Detection.Method) {
        Write-Error ("[$Name] Invalid component detection method specified: " + $Metadata.Component.Detection.Method)
    }

    # If the component isn't available don't bother determining the install path
    if ($Component.Availability -notin ('Available', 'AlwaysInstall')) {
        return $Component
    }

    # Configure component installation path
    if ($PSCmdlet.ParameterSetName -eq 'New' -and
        !$Metadata.Component.InstallPath.SpecialFolder -and
        !$Metadata.Component.InstallPath.Destination) {
        $Component.InstallPath = [Environment]::GetFolderPath('UserProfile')
    } elseif ($Metadata.Component.InstallPath.SpecialFolder -or
              $Metadata.Component.InstallPath.Destination) {
        $SpecialFolder = $Metadata.Component.InstallPath.SpecialFolder
        $Destination = $Metadata.Component.InstallPath.Destination

        if (!$SpecialFolder -and !$Destination) {
            $Component.InstallPath = [Environment]::GetFolderPath('UserProfile')
        } elseif (!$SpecialFolder -and $Destination) {
            if ([System.IO.Path]::IsPathRooted($Destination)) {
                if (Test-Path $Destination -PathType Container -IsValid) {
                    $Component.InstallPath = $Destination
                } else {
                    Write-Error "[$Name] The destination path for symlinking is invalid: $Destination"
                }
            } else {
                Write-Error "[$Name] The destination path for symlinking is not an absolute path: $Destination"
            }
        } elseif ($SpecialFolder -and !$Destination) {
            $Component.InstallPath = [Environment]::GetFolderPath($SpecialFolder)
        } else {
            if (!([System.IO.Path]::IsPathRooted($Destination))) {
                $InstallPath = Join-Path ([Environment]::GetFolderPath($SpecialFolder)) $Destination
                if (Test-Path $InstallPath -PathType Container -IsValid) {
                    $Component.InstallPath = $InstallPath
                } else {
                    Write-Error "[$Name] The destination path for symlinking is invalid: $InstallPath"
                }
            } else {
                Write-Error "[$Name] The destination path for symlinking is not a relative path: $Destination"
            }
        }
    }

    # Configure component symlink hiding
    if ($Metadata.Component.InstallPath.HideSymlinks) {
        $HideSymlinks = $Metadata.Component.InstallPath.HideSymlinks
        if ($HideSymlinks -eq 'True') {
            $Component.HideSymlinks = $true
        } elseif ($HideSymlinks -notin ('True', 'False')) {
            Write-Error "[$Name] Invalid HideSymlinks setting: $HideSymlinks"
        }
    }

    # Configure component ignore paths
    if ($Metadata.Component.IgnorePaths.Path) {
        foreach ($Path in $Metadata.Component.IgnorePaths.Path) {
            $Component.IgnorePaths += $Path
        }
    }

    return $Component
}

Function Install-DotFilesComponentDirectory {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [Component]$Component,
        [Parameter(Mandatory=$true)]
            [System.IO.DirectoryInfo[]]$Directories,
        [Parameter(Mandatory=$false)]
            [Switch]$TestOnly,
        [Parameter(Mandatory=$false)]
            [Switch]$Silent
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($Directory in $Directories) {
        if ($Directory.FullName -eq $SourcePath.FullName) {
            $TargetDirectory = $InstallPath
        } else {
            $SourceDirectoryRelative = $Directory.FullName.Substring($SourcePath.FullName.Length + 1)
            $TargetDirectory = Join-Path $InstallPath $SourceDirectoryRelative
            if ($SourceDirectoryRelative -in $Component.IgnorePaths) {
                if (!$Silent) {
                    Write-Verbose "[$Name] Ignoring directory path: $SourceDirectoryRelative"
                }
                continue
            }
        }

        if (Test-Path $TargetDirectory) {
            $ExistingTarget = Get-Item $TargetDirectory -Force
            if ($ExistingTarget -isnot [System.IO.DirectoryInfo]) {
                if (!$Silent) {
                    Write-Error "[$Name] Expected a directory but found a file with the same name: $TargetDirectory"
                }
                $Results += $false
            } elseif ($ExistingTarget.LinkType -eq 'SymbolicLink') {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($Directory.FullName -eq $SymlinkTarget)) {
                    if (!$Silent) {
                        Write-Error "[$Name] Symlink already exists but points to unexpected target: `"$TargetDirectory`" -> `"$SymlinkTarget`""
                    }
                    $Results += $false
                } else {
                    if (!$Silent) {
                        Write-Debug "[$Name] Symlink already exists and points to expected target: `"$TargetDirectory`" -> `"$SymlinkTarget`""
                    }
                    $Results += $true
                }
            } else {
                $NextFiles = Get-ChildItem $Directory.FullName -File -Force
                if ($NextFiles) {
                    if (!$TestOnly -and !$Silent) {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles
                    } elseif (!$TestOnly -and $Silent) {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles -Silent
                    } elseif ($TestOnly -and !$Silent) {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles -TestOnly
                    } else {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles -TestOnly -Silent
                    }
                }

                $NextDirectories = Get-ChildItem $Directory.FullName -Directory -Force
                if ($NextDirectories) {
                    if (!$TestOnly -and !$Silent) {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories
                    } elseif (!$TestOnly -and $Silent) {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Silent
                    } elseif ($TestOnly -and !$Silent) {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -TestOnly
                    } else {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -TestOnly -Silent
                    }
                }
            }
        } else {
            if (!$Silent) {
                Write-Verbose ("[$Name] Linking directory: `"$TargetDirectory`" -> `"" + $Directory.FullName + "`"")
                if ($TestOnly) {
                    New-Item -ItemType SymbolicLink -Path $TargetDirectory -Value $Directory.FullName -WhatIf
                } else {
                    $Symlink = New-Item -ItemType SymbolicLink -Path $TargetDirectory -Value $Directory.FullName
                    if ($Component.HideSymlinks) {
                        if (!$Silent) {
                            Write-Debug "[$Name] Setting attributes to hide directory symlink: `"$TargetDirectory`""
                        }
                        $Attributes = Set-SymlinkAttributes -Symlink $Symlink
                        if (!$Attributes) {
                            Write-Error "[$Name] Unable to set Hidden and System attributes on directory symlink: `"$TargetDirectory`""
                        }
                    }
                }
            }
            $Results += $true
        }
    }

    return $Results
}

Function Install-DotFilesComponentFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [Component]$Component,
        [Parameter(Mandatory=$true)]
            [System.IO.FileInfo[]]$Files,
        [Parameter(Mandatory=$false)]
            [Switch]$TestOnly,
        [Parameter(Mandatory=$false)]
            [Switch]$Silent
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($File in $Files) {
        $SourceFileRelative = $File.FullName.Substring($SourcePath.FullName.Length + 1)
        $TargetFile = Join-Path $Component.InstallPath $SourceFileRelative

        if ($SourceFileRelative -in $Component.IgnorePaths) {
            if (!$Silent) {
                Write-Verbose "[$Name] Ignoring file path: $SourceFileRelative"
            }
            continue
        }

        if (Test-Path $TargetFile) {
            $ExistingTarget = Get-Item $TargetFile -Force
            if ($ExistingTarget -isnot [System.IO.FileInfo]) {
                if (!$Silent) {
                    Write-Error "[$Name] Expected a file but found a directory with the same name: $TargetFile"
                }
                $Results += $false
            } elseif ($ExistingTarget.LinkType -ne 'SymbolicLink') {
                if (!$Silent) {
                    Write-Error "[$Name] Unable to create symlink as a file with the same name already exists: $TargetFile"
                }
                $Results += $false
            } else {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($File.FullName -eq $SymlinkTarget)) {
                    if (!$Silent) {
                        Write-Error "[$Name] Symlink already exists but points to unexpected target: `"$TargetFile`" -> `"$SymlinkTarget`""
                    }
                    $Results += $false
                } else {
                    if (!$Silent) {
                        Write-Debug "[$Name] Symlink already exists and points to expected target: `"$TargetFile`" -> `"$SymlinkTarget`""
                    }
                    $Results += $true
                }
            }
        } else {
            if (!$Silent) {
                Write-Verbose ("[$Name] Linking file: `"$TargetFile`" -> `"" + $File.FullName  + "`"")
                if ($TestOnly) {
                    New-Item -ItemType SymbolicLink -Path $TargetFile -value $File.FullName -WhatIf
                } else {
                    $Symlink = New-Item -ItemType SymbolicLink -Path $TargetFile -Value $File.FullName
                    if ($Component.HideSymlinks) {
                        if (!$Silent) {
                            Write-Debug "[$Name] Setting attributes to hide file symlink: `"$TargetFile`""
                        }
                        $Attributes = Set-SymlinkAttributes -Symlink $Symlink
                        if (!$Attributes) {
                            Write-Error "[$Name] Unable to set Hidden and System attributes on file symlink: `"$TargetFile`""
                        }
                    }
                }
            }
            $Results += $true
        }
    }

    return $Results
}

Function Remove-DotFilesComponentDirectory {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [Component]$Component,
        [Parameter(Mandatory=$true)]
            [System.IO.DirectoryInfo[]]$Directories,
        [Parameter(Mandatory=$false)]
            [Switch]$TestOnly,
        [Parameter(Mandatory=$false)]
            [Switch]$Silent
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($Directory in $Directories) {
        if ($Directory.FullName -eq $SourcePath.FullName) {
            $TargetDirectory = $InstallPath
        } else {
            $SourceDirectoryRelative = $Directory.FullName.Substring($SourcePath.FullName.Length + 1)
            $TargetDirectory = Join-Path $InstallPath $SourceDirectoryRelative
            if ($SourceDirectoryRelative -in $Component.IgnorePaths) {
                if (!$Silent) {
                    Write-Verbose "[$Name] Ignoring directory path: $SourceDirectoryRelative"
                }
                continue
            }
        }

        if (Test-Path $TargetDirectory) {
            $ExistingTarget = Get-Item $TargetDirectory -Force
            if ($ExistingTarget -isnot [System.IO.DirectoryInfo]) {
                if (!$Silent) {
                    Write-Warning "[$Name] Expected a directory but found a file with the same name: $TargetDirectory"
                }
            } elseif ($ExistingTarget.LinkType -eq 'SymbolicLink') {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($Directory.FullName -eq $SymlinkTarget)) {
                    if (!$Silent) {
                        Write-Error "[$Name] Symlink already exists but points to unexpected target: `"$TargetDirectory`" -> `"$SymlinkTarget`""
                    }
                    $Results += $false
                } else {
                    if (!$Silent) {
                        Write-Verbose ("[$Name] Removing directory symlink: `"$TargetDirectory`" -> `"" + $Directory.FullName  + "`"")
                        if ($TestOnly) {
                            Write-Warning "Will remove directory symlink using native rmdir: $TargetDirectory"
                        } else {
                            $Attributes = Set-SymlinkAttributes -Symlink $ExistingTarget -Remove
                            if (!$Attributes) {
                                Write-Error "[$Name] Unable to remove Hidden and System attributes on directory symlink: `"$TargetDirectory`""
                            }

                            # Apparently despite PowerShell 5.0's new symlink support you can't
                            # remove a directory symlink without recursively deleting its contents!
                            cmd /c "rmdir `"$TargetDirectory`"" | Out-Null
                        }
                    }
                    $Results += $true
                }
            } else {
                $NextFiles = Get-ChildItem $Directory.FullName -File -Force
                if ($NextFiles) {
                    if (!$TestOnly -and !$Silent) {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles
                    } elseif (!$TestOnly -and $Silent) {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles -Silent
                    } elseif ($TestOnly -and !$Silent) {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles -TestOnly
                    } else {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles -TestOnly -Silent
                    }
                }

                $NextDirectories = Get-ChildItem $Directory.FullName -Directory -Force
                if ($NextDirectories) {
                    if (!$TestOnly -and !$Silent) {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories
                    } elseif (!$TestOnly -and $Silent) {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Silent
                    } elseif ($TestOnly -and !$Silent) {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -TestOnly
                    } else {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -TestOnly -Silent
                    }
                }
            }
        } else {
            if (!$Silent) {
                Write-Warning "[$Name] Expected a directory but found nothing: $TargetDirectory"
            }
        }
    }

    return $Results
}

Function Remove-DotFilesComponentFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [Component]$Component,
        [Parameter(Mandatory=$true)]
            [System.IO.FileInfo[]]$Files,
        [Parameter(Mandatory=$false)]
            [Switch]$TestOnly,
        [Parameter(Mandatory=$false)]
            [Switch]$Silent
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($File in $Files) {
        $SourceFileRelative = $File.FullName.Substring($SourcePath.FullName.Length + 1)
        $TargetFile = Join-Path $Component.InstallPath $SourceFileRelative

        if ($SourceFileRelative -in $Component.IgnorePaths) {
            if (!$Silent) {
                Write-Verbose "[$Name] Ignoring file path: $SourceFileRelative"
            }
            continue
        }

        if (Test-Path $TargetFile) {
            $ExistingTarget = Get-Item $TargetFile -Force
            if ($ExistingTarget -isnot [System.IO.FileInfo]) {
                if (!$Silent) {
                    Write-Warning "[$Name] Expected a file but found a directory with the same name: $TargetFile"
                }
            } elseif ($ExistingTarget.LinkType -ne 'SymbolicLink') {
                if (!$Silent) {
                    Write-Warning "[$Name] Found a file instead of a symbolic link so not removing: $TargetFile"
                }
            } else {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($File.FullName -eq $SymlinkTarget)) {
                    if (!$Silent) {
                        Write-Error "[$Name] Symlink already exists but points to unexpected target: `"$TargetFile`" -> `"$SymlinkTarget`""
                    }
                    $Results += $false
                } else {
                    if (!$Silent) {
                        Write-Verbose ("[$Name] Removing file symlink: `"$TargetFile`" -> `"" + $File.FullName  + "`"")
                        if ($TestOnly){
                            Remove-Item $TargetFile -WhatIf
                        } else {
                            Remove-Item $TargetFile -Force
                        }
                    }
                    $Results += $true
                }
            }
        } else {
            if (!$Silent) {
                Write-Warning "[$Name] Expected a file but found nothing: $TargetFile"
            }
        }
    }

    return $Results
}

Function Set-SymlinkAttributes {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.IO.FileSystemInfo]$Symlink,
        [Parameter(Mandatory=$false)]
            [Switch]$Remove
    )

    if ($Symlink.LinkType -ne 'SymbolicLink') {
        return $false
    }

    $HiddenAttribute   = [System.IO.FileAttributes]::Hidden
    $SystemAttribute   = [System.IO.FileAttributes]::System

    if (!$Remove) {
        $Symlink.Attributes = ($Symlink.Attributes -bor $HiddenAttribute)
        $Symlink.Attributes = ($Symlink.Attributes -bor $SystemAttribute)
    } else {
        if ($CurrentAttributes -band $SystemAttribute) {
            $Symlink.Attributes = ($CurrentAttributes -bxor $SystemAttribute)
        }
        if ($CurrentAttributes -band $HiddenAttribute) {
            $Symlink.Attributes = ($CurrentAttributes -bxor $HiddenAttribute)
        }
    }

    return $true
}

Function Test-DotFilesPath {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Path
    )

    if (Test-Path $Path) {
        $PathItem = Get-Item $Path -Force
        if ($PathItem -is [System.IO.DirectoryInfo]) {
            $PathLink = Get-SymlinkTarget -Symlink $PathItem
            if ($PathLink) {
                return (Test-DotFilesPath $PathLink)
            }
            return $PathItem
        }
    }
    return $false
}

Function Test-IsAdministrator {
    [CmdletBinding()]
    Param()

    $User = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($User.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        return $true
    }
    return $false
}

Enum Availability {
    # The component was detected
    Available
    # The component was not detected
    Unavailable
    # The component will be ignored
    #
    # This is distinct from "Unavailable" as it indicates the component is not
    # available on the underlying platform.
    Ignored
    # The component will always be installed
    AlwaysInstall
    # The component will never be installed
    NeverInstall
    # A failure occurred during component detection
    DetectionFailure
    # No detection logic was available
    NoLogic
}

Enum InstallState {
    # The component is installed
    Installed
    # The component is not installed
    NotInstalled
    # The component is partially installed
    #
    # After Get-DotFiles this typically means either:
    #  - Additional files have been added since it was last installed
    #  - A previous installation attempt was only partially successful
    #
    # After Install-DotFiles or Remove-DotFiles this typically means errors were
    # encountered during the installation or removal operation (or simulation).
    PartialInstall
    # The install state of the component can't be determined
    #
    # This can occur when attempting to install a component that has no files or
    # folders (because they're all ignored via the metadata or there are none).
    Unknown
    # The install state of the component has yet to be determined
    NotEvaluated
}

Class Component {
    # REQUIRED: This should match the corresponding dotfiles directory
    [String]$Name
    # REQUIRED: The availability state per the Availability enumeration
    [Availability]$Availability = [Availability]::DetectionFailure

    # OPTIONAL: Friendly name if one was provided or could be located
    [String]$FriendlyName
    # OPTIONAL: Hides newly created symlinks per the <HideSymlinks> element
    [Boolean]$HideSymlinks

    # INTERNAL: This will be set automatically based on the component name
    [System.IO.DirectoryInfo]$SourcePath
    # INTERNAL: Uninstall Registry key (populated by Find-DotFilesComponent)
    [String]$UninstallKey
    # INTERNAL: Determined by the <SpecialFolder> and <Destination> elements
    [String]$InstallPath
    # INTERNAL: Automatically set based on the <Path> elements in <IgnorePaths>
    [String[]]$IgnorePaths
    # INTERNAL: This will be set automatically during detection and installation
    [InstallState]$State = [InstallState]::NotEvaluated

    Component([String]$Name, [System.IO.DirectoryInfo]$DotFilesPath) {
        $this.Name = $Name
        $this.SourcePath = (Get-Item (Resolve-Path (Join-Path $DotFilesPath $Name)))
    }
}
