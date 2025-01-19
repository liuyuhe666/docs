Write-Output "---- 开始执行 ----"
$t = Get-Date -Format "yyyyMMddHHmmss"
git add .
git commit -m "✨: $t"
git push
Write-Output "---- 执行结束 ----"