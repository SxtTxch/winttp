$listener = New-Object System.Net.HttpListener

$port = 8000 # Specify the port to run the HTTP Server on.
$server = "127.0.0.1"
$base_dir = "C:\http" # Specify the root directory for serving files.
$default_filenames = @("index.html", "index.htm", "default.html")

Write-Output "Starting server at ${server}:${port}" # Debug message to indicate server start.

$listener.Prefixes.Add("http://${server}:${port}/")
$listener.Start()
function Get-NormalizedPath($base_dir, $RequestUrl) { # Function to normalize the requested URL path, Converting it from a network path to a local file system path, localized in the base directory.
    $raw_url_path = ([uri]$RequestUrl).AbsolutePath
    $clean_path = $raw_url_path -split '[?#]' | Select-Object -First 1
    $clean_path = [uri]::UnescapeDataString($clean_path)
    $clean_path = $clean_path.TrimStart("/\")
    $unsafe_path = Join-Path $base_dir $clean_path
    $normalized_path = [System.IO.Path]::GetFullPath($unsafe_path)
    if (-not ($normalized_path.StartsWith($base_dir))) {
        return $null
    }
    return $normalized_path
}
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $response = $context.Response
    $HttpMethod = $context.Request.HttpMethod
    $RequestUrl = $context.Request.Url.ToString()
    $path = Get-NormalizedPath $base_dir $RequestUrl
    $fileName = [System.IO.Path]::GetFileName($RequestUrl)

    if ( (Get-Item $path).PSIsContainer ) { # If the requested path is a directory, look for default files listed in $default_filenames.
        $foundFile = $null
        foreach ($defaultFile in $default_filenames) {
            $defaultFilePath = Join-Path $path $defaultFile
            if (Test-Path $defaultFilePath) {
                $foundFile = $defaultFilePath
                break
            }
        }
        if (-not $foundFile) {
            $response.StatusCode = 404
            $response.StatusDescription = "Not Found"
            $response.Close()
            continue
        }
        $filePath = $foundFile
    } else {
        $filePath = $path
    }

    if (-not $path -or -not (Test-Path $path)) {
        $response.StatusCode = 404
        $response.StatusDescription = "Not Found"
        $response.Close()
        continue
    }

    $currentFile = $_.Name
    $content = [System.IO.File]::ReadAllText($filePath)
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)

    switch ([System.IO.Path]::GetExtension($filePath).ToLower()) { # Current file extension support.
    ".html" { $contentType = "text/html" }
    ".htm" { $contentType = "text/html" }
    ".css" { $contentType = "text/css" }
    ".js" { $contentType = "application/javascript" }
    ".png" { $contentType = "image/png" }
    ".jpg" { $contentType = "image/jpeg" }
    ".jpeg" { $contentType = "image/jpeg" }
    ".gif" { $contentType = "image/gif" }
    default { $contentType = "application/octet-stream" }

    }

    $response.ContentType = $contentType
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
}


