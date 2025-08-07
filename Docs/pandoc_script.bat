pandoc "manual.md" -o manual.html -d defaults.yaml --embed-resources=true
@REM pandoc "manual.md" -o manual.pdf -d defaults.yaml --template=template/yuki.tex -H head.tex
pandoc "manual.md" -o manual.pdf -H head.tex --pdf-engine=lualatex