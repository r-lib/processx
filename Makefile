
all: README.md

README.md: README.Rmd
	R -e "library(knitr); knit('$<', output = '$@', quiet = FALSE)"
