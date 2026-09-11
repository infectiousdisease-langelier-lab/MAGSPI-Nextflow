.PHONY: check test stub image image-apptainer

check:
	python -m py_compile bin/*.py

test: check
	@echo "Run: nextflow run . -profile test"

stub:
	nextflow run . -profile test -stub-run

image:
	docker build -f containers/Dockerfile -t magspi:0.2.0 .

image-apptainer:
	apptainer build magspi-0.2.0.sif docker-daemon://magspi:0.2.0
