
all: README.markdown

README.markdown: README.Rmd
	R -e "library(knitr); knit('$<', output = '$@', quiet = FALSE)"
