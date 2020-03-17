build:
	 pandoc --highlight-style kate \
		 --listings \
		 -H ./latex-tpl/listings-setup.tex \
		 -V pagestyle=empty  \
		 -s README.md REQUIREMENTS.md \
		 	./lesson01-getting-started/README.md \
			./lesson02-logging/README.md \
			./lesson03-influxdb/README.md \
			./lesson04-tracing/README.md \
			./lesson0x-justforpro/README.md \
		 	./SOLUTION.md \
		 	./lesson01-getting-started/SOLUTIONS.md \
		 	./lesson02-logging/SOLUTIONS.md \
		 	./lesson03-influxdb/SOLUTIONS.md \
		 	./lesson04-tracing/SOLUTIONS.md \
			--toc \
		 -o workshop.pdf
