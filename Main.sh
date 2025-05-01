#!/bin/sh

#Get your data prepared
wget https://sra-pub-run-odp.s3.amazonaws.com/sra/SRR10102333/SRR10102333
wget https://sra-pub-run-odp.s3.amazonaws.com/sra/SRR10102255/SRR10102255
#Convert SRR files to fastq files
fastq-dump --split-3 SRR10102333
fastq-dump --split-3 SRR10102255

#Input data
conda activate qiime2-amplicon-2024.10  #Your own environment
#Generate manifest.tsv file
echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" > manifest.tsv
for f in *_1.fastq
do
  sample=$(basename "$f" | sed 's/_1\.fastq//')
  fwd=$(readlink -f "$f")
  rev=$(readlink -f "${sample}_2.fastq")
  echo -e "${sample}\t${fwd}\t${rev}" >> manifest.tsv
done

qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path manifest.tsv \
  --output-path demux.qza \
  --input-format PairedEndFastqManifestPhred33V2

#Analyze
#Quality Control
qiime dada2 denoise-single \
  --i-demultiplexed-seqs demux.qza \
  --p-trim-left 0 \
  --p-trunc-len 120 \
  --o-representative-sequences rep-seqs-dada2.qza \
  --o-table table-dada2.qza \
  --o-denoising-stats stats-dada2.qza
#Download classifier
wget https://data.qiime2.org/2024.2/common/silva-138-99-nb-classifier.qza  #If failed, please use local transmission
#Species annotation
qiime feature-classifier classify-sklearn \
  --i-classifier silva-138-99-nb-classifier.qza \
  --i-reads rep-seqs-dada2.qza \
  --o-classification taxonomyall.qza  #Please ensure that sufficient memory is available (around 16 GB would be adequate).
#Extracting genus-level species annotations
qiime taxa collapse \
  --i-table table-dada2.qza \
  --i-taxonomy taxonomyall.qza \
  --p-level 6 \
  --o-collapsed-table table-16_2.qza
#Export species annotations
qiime tools export \
  --input-path table-16_2.qza \
  --output-path test
#Convert to tsv file
biom convert -i feature-table.biom -o table.tsv --to-tsv
