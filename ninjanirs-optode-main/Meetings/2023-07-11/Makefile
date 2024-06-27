
DOCO := hazen_ninja_readout

PDF := ${DOCO}.pdf
TEX := ${DOCO}.tex
FIGS := figs/BU_ATLAS.png

all: ${PDF}

${PDF}: ${TEX} ${FIGS}
	pdflatex ${TEX}
	pdflatex ${TEX}

clean:
	rm -f *.aux *.nav *.out *.snm *.toc *.log *~ \#*


