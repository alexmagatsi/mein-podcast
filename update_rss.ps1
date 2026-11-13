# 1. Immer den frischen Original-Feed von podcaster.de laden, damit keine halb-geänderten Daten genutzt werden
$xmlContent = (Invoke-WebRequest -Uri "https://rstb09.podcaster.de/podcast.rss" -UseBasicParsing).Content

[xml]$rss = $xmlContent
$baseRepoUrl = "https://raw.githubusercontent.com/alexmagatsi/mein-podcast/main"
$pagesFeedUrl = "https://alexmagatsi.github.io/mein-podcast/podcast.rss"

# 2. XSLT-Stylesheet-Verweis entfernen
$xslNode = $rss.SelectSingleNode("processing-instruction('xml-stylesheet')")
if ($xslNode) {
    $rss.RemoveChild($xslNode) | Out-Null
}

# 3. Namespaces definieren
$ns = New-Object System.Xml.XmlNamespaceManager($rss.NameTable)
$ns.AddNamespace("atom", "http://www.w3.org/2005/Atom")
$ns.AddNamespace("itunes", "http://www.itunes.com/dtds/podcast-1.0.dtd")

# 4. Feed Self-Link auf GitHub Pages umstellen
$selfLink = $rss.SelectSingleNode("//atom:link[@rel='self']", $ns)
if ($selfLink) {
    $selfLink.SetAttribute("href", $pagesFeedUrl)
}

# 5. Globales Podcast-Cover exakt über den XML-Knoten ansprechen
$channelImgUrlNode = $rss.SelectSingleNode("/rss/channel/image/url")
if ($channelImgUrlNode) {
    $oldCoverUrl = $channelImgUrlNode.InnerText
    $mainCoverName = "podcast_cover.jpg"
    $mainCoverPath = Join-Path $PSScriptRoot $mainCoverName
    if (-not (Test-Path $mainCoverPath)) {
        try { Invoke-WebRequest -Uri $oldCoverUrl -OutFile $mainCoverPath -ErrorAction SilentlyContinue } catch {}
    }
    $newMainCoverUrl = "$baseRepoUrl/$mainCoverName"
    $channelImgUrlNode.InnerText = $newMainCoverUrl

    $itunesMainImg = $rss.SelectSingleNode("/rss/channel/itunes:image", $ns)
    if ($itunesMainImg) {
        $itunesMainImg.SetAttribute("href", $newMainCoverUrl)
    }
}

# 6. Alle Episoden durchgehen und Pfade exakt mappen
$items = $rss.SelectNodes("/rss/channel/item")
foreach ($item in $items) {
    # Exakt das direkte <title>-Kindelement auslesen (verhindert Array-Fehler)
    $titleNode = $item.SelectSingleNode("title")
    $rawTitle = if ($titleNode) { $titleNode.InnerText } else { "" }
    $cleanTitle = $rawTitle -replace '[\\/?:*"<>|]', ''
    $episodeDir = Join-Path $PSScriptRoot $cleanTitle
    $encodedFolder = [System.Uri]::EscapeDataString($cleanTitle)

    # MP3-URL anpassen
    $enclosureNode = $item.SelectSingleNode("enclosure")
    if ($enclosureNode) {
        $mp3Url = $enclosureNode.GetAttribute("url")
        if ($mp3Url) {
            $mp3Name = $mp3Url.Split('/')[-1].Split('?')[0]
            $encodedMp3 = [System.Uri]::EscapeDataString($mp3Name)
            $enclosureNode.SetAttribute("url", "$baseRepoUrl/$encodedFolder/$encodedMp3")
        }
    }

    # Episoden-Cover-URL anpassen
    $itunesEpImg = $item.SelectSingleNode("itunes:image", $ns)
    if ($itunesEpImg -and (Test-Path $episodeDir)) {
        $coverFile = Get-ChildItem -Path $episodeDir -Filter "cover.*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($coverFile) {
            $encodedCover = [System.Uri]::EscapeDataString($coverFile.Name)
            $itunesEpImg.SetAttribute("href", "$baseRepoUrl/$encodedFolder/$encodedCover")
        }
    }
}

# 7. Fertige podcast.rss speichern
$outputPath = Join-Path $PSScriptRoot "podcast.rss"
$rss.Save($outputPath)
Write-Host "Erfolgreich! Alle $($items.Count) Episoden wurden fehlerfrei in podcast.rss aktualisiert." -ForegroundColor Green