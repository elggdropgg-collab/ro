# Searches the Roblox Creator Store for audio from licensed libraries.
#
#   .\tools\find-sounds.ps1 "bone crack"
#   .\tools\find-sounds.ps1 "scream" -MaxSeconds 3
#   .\tools\find-sounds.ps1 "wind" -AnyCreator
#
# By default only the Pro Sound Effects library is shown: it is licensed by Roblox for use
# in any experience and will not disappear to moderation like random user uploads.

param(
	[Parameter(Mandatory = $true)][string]$Query,
	[int]$MinSeconds = 0,
	[int]$MaxSeconds = 100000,
	[int]$Pages = 2,
	[switch]$AnyCreator
)

$trusted = @("ProSoundEffects")
$token = $null
$seen = @{}
for ($page = 0; $page -lt $Pages; $page++) {
	$url = "https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=Audio&maxPageSize=100&query=" + [uri]::EscapeDataString($Query)
	if ($token) { $url += "&pageToken=" + [uri]::EscapeDataString($token) }
	$data = Invoke-RestMethod $url
	foreach ($item in $data.creatorStoreAssets) {
		$a = $item.asset
		if ($seen.ContainsKey($a.id)) { continue }
		$seen[$a.id] = $true
		if (-not $AnyCreator -and $trusted -notcontains $item.creator.name) { continue }
		if ($a.durationSeconds -lt $MinSeconds -or $a.durationSeconds -gt $MaxSeconds) { continue }
		[pscustomobject]@{
			Id = $a.id
			Sec = $a.durationSeconds
			Title = $a.title
			Category = "$($a.category)/$($a.subcategory)"
			Creator = $item.creator.name
		}
	}
	$token = $data.nextPageToken
	if (-not $token) { break }
}
