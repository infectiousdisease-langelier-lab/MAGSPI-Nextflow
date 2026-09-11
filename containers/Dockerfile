FROM mambaorg/micromamba:2.9.0-debian13

LABEL org.opencontainers.image.title="MAGSPI"
LABEL org.opencontainers.image.description="Containerized MAGSPI metagenomic MAG recovery and strain profiling workflow"
LABEL org.opencontainers.image.licenses="MIT"

COPY --chown=$MAMBA_USER:$MAMBA_USER envs/mags_pipeline.yml /tmp/mags_pipeline.yml

RUN micromamba create --yes --name mags-pipeline --file /tmp/mags_pipeline.yml && \
    micromamba clean --all --yes

ENV PATH=/opt/conda/envs/mags-pipeline/bin:$PATH
ENV CONDA_DEFAULT_ENV=mags-pipeline

WORKDIR /workspace
USER $MAMBA_USER

ENTRYPOINT ["/bin/bash"]
