# RSS-Feed herunterladen, falls noch nicht geschehen
$rssUrl = "https://rstb09.podcaster.de/podcast.rss"
[xml]$rss = (Invoke-WebRequest -Uri $rssUrl -UseBasicParsing).Content

# Durch alle Episoden im Feed iterieren
foreach ($item in $rss.rss.channel.item) {
    # Titel bereinigen, damit er als Ordnername taugt (ungültige Zeichen entfernen)
    $cleanTitle = $item.title -replace '[\\/?:*"<>|]', ''
    $episodeDir = Join-Path $PSScriptRoot $cleanTitle
    
    if (-not (Test-Path $episodeDir)) {
        New-Item -ItemType Directory -Path $episodeDir | Out-Null
    }

    # 1. Beschreibung als text.txt speichern
    $description = $item.description
    # HTML-Tags grob entfernen für lesbaren Text
    $cleanDesc = [System.Text.RegularExpressions.Regex]::Replace($description, "<[^>]*>", "")
    Set-Content -Path (Join-Path $episodeDir "beschreibung.txt") -Value $cleanDesc -Encoding UTF8

    # 2. Episoden-Cover (falls vorhanden) herunterladen
    $imageUrl = $item.image.href
    if (-not $imageUrl) {
        # Fallback auf das globale Podcast-Cover im Channel
        $imageUrl = $rss.rss.channel.image.url
    }
    
    if ($imageUrl) {
        $imgExtension = [System.IO.Path]::GetExtension($imageUrl.Split('?')[0])
        if (-not $imgExtension) { $imgExtension = ".jpg" }
        $imgFile = Join-Path $episodeDir "cover$imgExtension"
        try {
            Invoke-WebRequest -Uri $imageUrl -OutFile $imgFile -ErrorAction SilentlyContinue
        } catch {}
    }

    # 3. Falls die MP3 schon im Hauptordner liegt, verschieben wir sie gleich in den passenden Episoden-Ordner
    $mp3Url = $item.enclosure.url
    if ($mp3Url) {
        $mp3Name = $mp3Url.Split('/')[-1].Split('?')[0]
        $sourceMp3 = Join-Path $PSScriptRoot $mp3Name
        $targetMp3 = Join-Path $episodeDir $mp3Name
        if ((Test-Path $sourceMp3) -and (-not (Test-Path $targetMp3))) {
            Move-Item -Path $sourceMp3 -Destination $targetMp3
        }
    }
}
Write-Host "Fertig! Alle Beschreibungen und Cover wurden einsortiert." -ForegroundColor Green