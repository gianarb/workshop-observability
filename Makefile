buid:
	 pandoc --highlight-style kate \
		 -s README.md REQUIREMENTS.md ./lesson01-getting-started/README.md ./lesson02-logging/README.md lesson03-influxdb/README.md lesson04-tracing/README.md lesson0x-justforpro/README.md \
		 -o workshop.pdf
