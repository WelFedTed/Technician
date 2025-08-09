pandoc "manual.md" -o manual.html -d defaults.yaml --embed-resources=true
@REM pandoc "manual.md" -o manual.pdf -d defaults.yaml --template=template/yuki.tex -H head.tex
pandoc "manual.md" -o manual.pdf -H head.tex --pdf-engine=lualatex

@REM pandoc test.md -o test.pdf -d defaults.yaml --template=template/yuki.tex -H head.tex

@REM use eisvogel template for PDF output
@REM ---------------------------------------------
pandoc test.md -o test.pdf --from markdown --template template/eisvogel --listings --metadata-file metadata.yaml --table-of-contents -V titlepage=true