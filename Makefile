VERSION := $(shell cat VERSION)

.PHONY: check test stub unit profiles image image-apptainer clean

## compile helpers and validate layout
check:
	python3 -m py_compile bin/*.py
	python3 -m json.tool nextflow_schema.json > /dev/null
	./scripts/validate_repo.sh

## helper-script unit tests (no Nextflow, no containers)
unit:
	python3 tests/test_bin_scripts.py

## every process runs its stub -- no tools, containers or databases needed
stub:
	nextflow run . -profile test_stub -stub-run --outdir results_stub

## confirm every profile resolves
profiles:
	for p in standard docker apptainer singularity conda slurm test test_stub; do \
	    nextflow config -profile $$p . > /dev/null || exit 1; \
	done

## real tools on the simulated mini-metagenome (downloads references first)
test: check unit
	python3 tests/make_test_data.py --outdir tests/data
	nextflow run . -profile test,docker --outdir results_test

## optional single-image build -- see docs/container.md before using
image:
	docker build -f containers/Dockerfile -t magspi:$(VERSION) .

image-apptainer: image
	apptainer build magspi-$(VERSION).sif docker-daemon://magspi:$(VERSION)

clean:
	rm -rf work work_* results results_* .nextflow .nextflow.log* tests/data
