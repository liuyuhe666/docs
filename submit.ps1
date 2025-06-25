$t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$msg = "update at $t"
Write-Output "$msg"
git add .
git commit -m "$msg"
git push
