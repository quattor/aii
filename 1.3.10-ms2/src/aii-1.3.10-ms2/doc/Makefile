# Build documentation


TARGET=aii

TEX=$(TARGET).tex

PDF=$(TARGET).pdf

all: pdf html

pdf: 
	pdflatex $(TARGET)
	pdflatex $(TARGET)

html:
	latex2html -html_version 3.2,math -scalable_fonts -no_navigation -verbosity 0 \
	           -split 0 -show_section_numbers -dir `pwd` -noinfo -noaddress $(TARGET)
	rm -f index.html

clean:
	@rm -f labels.pl WARNINGS internals.pl *.aux *.dvi *.pl *.toc *.log *.ps *~ *.out

veryclean: clean
	@rm -f $(PDF)

