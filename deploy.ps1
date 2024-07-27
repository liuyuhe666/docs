# 配合 GitHub Pages 实现一键部署
# 使用说明：开启 GitHub Pages 后，将该脚本放到项目的根目录，运行脚本
Write-Output "---- 开始执行 ----"
$t = Get-Date -Format "dddd MM/dd/yyyy HH:mm"
git add .
git commit -m "✨: Update $t"
git push
Write-Output "---- 执行结束 ----"