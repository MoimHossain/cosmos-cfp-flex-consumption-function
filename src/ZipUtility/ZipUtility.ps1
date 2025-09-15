# ZipUtility.ps1 - PowerShell version of the C# zip utility

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$SourceDirectory,
    
    [Parameter(Mandatory=$true, Position=1)]
    [string]$OutputZipPath,
    
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ExecutableFiles = @()
)

# Import required .NET assemblies
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Import System.IO.Compression.ZipFileExtensions for CreateEntryFromFile method
if (-not ([System.Management.Automation.PSTypeName]'System.IO.Compression.ZipFileExtensions').Type) {
    Add-Type -AssemblyName System.IO.Compression.ZipFile -ErrorAction SilentlyContinue
}

function New-DotNetZip {
    param(
        [string[]]$Files,
        [string]$RootPath,
        [string[]]$Executables
    )
    
    # Constants for Unix file permissions
    $CreatedByUnix = 3
    $CentralDirectorySignature = 0x02014B50
    $UnixExecutablePermissions = [Convert]::ToInt32("100777", 8) -shl 16
    $UnixReadWritePermissions = [Convert]::ToInt32("100666", 8) -shl 16
    
    $MemStream = New-Object System.IO.MemoryStream
    
    try {
        # Create ZIP archive
        $Zip = New-Object System.IO.Compression.ZipArchive($MemStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
          foreach ($File in $Files) {
            $EntryName = Get-ZipEntryName -FilePath $File -RootPath $RootPath
            
            # Use ZipFileExtensions.CreateEntryFromFile method
            $Entry = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Zip, $File, $EntryName)
            
            # Set permissions based on whether file is executable
            if ($Executables -contains $EntryName) {
                $Entry.ExternalAttributes = $UnixExecutablePermissions
            } else {
                $Entry.ExternalAttributes = $UnixReadWritePermissions
            }
        }
        
        $Zip.Dispose()
        
        # Fix central directory entries for Unix compatibility on Windows
        if ([System.OperatingSystem]::IsWindows()) {
            $MemStream.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
            
            while (Find-SignatureBackwards -Stream $MemStream -Signature $CentralDirectorySignature) {
                $MemStream.Seek(5, [System.IO.SeekOrigin]::Current) | Out-Null
                $MemStream.WriteByte($CreatedByUnix)
                $MemStream.Seek(-6, [System.IO.SeekOrigin]::Current) | Out-Null
            }
        }
        
        $MemStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        return $MemStream
    }
    catch {
        $MemStream.Dispose()
        throw
    }
}

function Find-SignatureBackwards {
    param(
        [System.IO.Stream]$Stream,
        [uint32]$Signature
    )
    
    $BufferPointer = 0
    $CurrentSignature = [uint32]0
    $Buffer = New-Object byte[] 32
    $OutOfBytes = $false
    $SignatureFound = $false
    
    while (-not $SignatureFound -and -not $OutOfBytes) {
        $OutOfBytes = Read-BackwardsFromStream -Stream $Stream -Buffer $Buffer -BufferPointer ([ref]$BufferPointer)
        
        while ($BufferPointer -ge 0 -and -not $SignatureFound) {
            $CurrentSignature = ($CurrentSignature -shl 8) -bor $Buffer[$BufferPointer]
            if ($CurrentSignature -eq $Signature) {
                $SignatureFound = $true
                break
            }
            $BufferPointer--
        }
    }
    
    if (-not $SignatureFound) {
        return $false
    }
    
    $Stream.Seek($BufferPointer, [System.IO.SeekOrigin]::Current) | Out-Null
    return $true
}

function Read-BackwardsFromStream {
    param(
        [System.IO.Stream]$Stream,
        [byte[]]$Buffer,
        [ref]$BufferPointer
    )
    
    if ($Stream.Position -ge $Buffer.Length) {
        $Stream.Seek(-$Buffer.Length, [System.IO.SeekOrigin]::Current) | Out-Null
        $Stream.ReadExactly($Buffer, 0, $Buffer.Length)
        $Stream.Seek(-$Buffer.Length, [System.IO.SeekOrigin]::Current) | Out-Null
        $BufferPointer.Value = $Buffer.Length - 1
        return $false
    }
    else {
        $BytesToRead = [int]$Stream.Position
        $Stream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        $Stream.ReadExactly($Buffer, 0, $BytesToRead)
        $Stream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        $BufferPointer.Value = $BytesToRead - 1
        return $true
    }
}

function Get-ZipEntryName {
    param(
        [string]$FilePath,
        [string]$RootPath
    )
    
    # Preserve directory structure starting from the root of the source directory
    # Remove the root path and normalize directory separators for zip format
    $relativePath = $FilePath.Substring($RootPath.Length).TrimStart('\', '/')
    return $relativePath.Replace('\', '/')
}

# Main execution logic
function Main {
    # Validate parameters
    if (-not $SourceDirectory -or -not $OutputZipPath) {
        Write-Host "Usage: .\ZipUtility.ps1 <sourceDirectory> <outputZipPath> [executableFile1 executableFile2 ...]"
        return
    }
    
    if (-not (Test-Path -Path $SourceDirectory -PathType Container)) {
        Write-Host "Error: Source directory '$SourceDirectory' does not exist." -ForegroundColor Red
        return
    }
    
    try {
        # Get all files in the source directory
        $Files = Get-ChildItem -Path $SourceDirectory -File -Recurse | ForEach-Object { $_.FullName }
        
        # Create the ZIP stream
        $ZipStream = New-DotNetZip -Files $Files -RootPath $SourceDirectory -Executables $ExecutableFiles
        
        # Write the ZIP stream to file
        $FileStream = [System.IO.File]::Create($OutputZipPath)
        try {
            $ZipStream.CopyTo($FileStream)
            Write-Host "ZIP file created at: $OutputZipPath" -ForegroundColor Green
        }
        finally {
            $FileStream.Dispose()
            $ZipStream.Dispose()
        }
    }
    catch {
        Write-Host "Error creating ZIP file: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Execute main function
Main
