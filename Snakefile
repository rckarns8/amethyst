# Grab a list of all the samples
# Assumes all the file names have the format R[12]_{sample}_R[12].fastq
import glob
import re

pattern = re.compile(r'00_data/fastq/R1/R1_(.*)_R1.fastq')
files = glob.glob('00_data/fastq/R1/R1_*.fastq')

SAMPLES = []
for file in files:
    match = pattern.match(file)
    if match:
        SAMPLES.append(match.group(1))

ruleorder: fastqc > multiqc > fastp > megahit > bbdb > bbmap > prodigal > prokka > interleave > sourmash > maxbin2 > checkm > dRep  
# Master rule that snakemake uses to determine which files need to be 
# generated.
rule all:
    input:
        expand("00_data/fastq/R1/R1_{sample}_R1.fastq", sample=SAMPLES),
        expand("00_data/fastq/R2/R2_{sample}_R2.fastq", sample=SAMPLES),
        expand("00_data/fastq/fastqc-R1/R1_{sample}_R1_fastqc.html", sample=SAMPLES),
        expand("00_data/fastq/fastqc-R2/R2_{sample}_R2_fastqc.html", sample=SAMPLES),
        "00_data/fastq/fastqc-R1/multiqc_report.html",
        "00_data/fastq/fastqc-R2/multiqc_report.html",
        expand("01_qc/trimmed_reads/test/{sample}_1.fq", sample=SAMPLES),
        expand("01_qc/trimmed_reads/test/{sample}_2.fq", sample=SAMPLES),
        expand("02_assembly/{sample}/{sample}.contigs.fa", sample=SAMPLES),
        expand("02_assembly/{sample}.1.bt2", sample=SAMPLES),
        expand("02_assembly/{sample}/{sample}.sam", sample=SAMPLES),
        expand("02_assembly/{sample}/prodigal/{sample}_contig_cords.gbk", sample=SAMPLES),
        expand("02_assembly/{sample}/prodigal/{sample}_contig_orfs.faa", sample=SAMPLES),
        expand("02_assembly/{sample}/prodigal/{sample}_contig_orfs.fna", sample=SAMPLES),
        expand("02_assembly/{sample}/prodigal/{sample}/{sample}.gff", sample=SAMPLES),
        expand("02_assembly/{sample}/prodigal/{sample}/{sample}.faa", sample=SAMPLES),
        expand("01_qc/trimmed_reads/test/{sample}_1.fq", sample=SAMPLES),
        expand("01_qc/trimmed_reads/test/{sample}_2.fq", sample=SAMPLES),
        expand("02_assembly/sourmash/tax_out/{sample}_sourmash_gather_out.csv", sample=SAMPLES),
        expand("02_assembly/{sample}_MaxBin.abundance", sample=SAMPLES),
        expand("02_assembly/{sample}/{sample}.contigs.fa", sample=SAMPLES),
        "02_assembly/dRep_out/log/logger.log",
        "03_assignment/GTDBtk/mashoutput.msh",
        "02_assembly/checkm/results/checkm.log", 
        "03_assignment/GTDBtk/gtdbtk.log",
        "README.md"


# Run all the samples through FastQC 
rule fastqc: 
    conda: 
        "mg-qc"
    input:
        r1 = "00_data/fastq/R1/R1_{sample}_R1.fastq",
        r2 = "00_data/fastq/R2/R2_{sample}_R2.fastq"
    output:
        o1 = "00_data/fastq/fastqc-R1/R1_{sample}_R1_fastqc.html", 
        o2 = "00_data/fastq/fastqc-R2/R2_{sample}_R2_fastqc.html"
    group: 1
    priority: 13
    params:
        outfolder1 = "00_data/fastq/fastqc-R1",
        outfolder2 = "00_data/fastq/fastqc-R2"
    threads: 5 
    log:
        "logs/fastqc/{sample}.log"
    benchmark:
        "benchmarks/fastqc/{sample}.txt"
    shell:
        """
        fastqc -t {threads} -o {params.outfolder1} {input.r1}
        fastqc -t {threads} -o {params.outfolder2} {input.r2}
        """

# Run MultiQC on the FastQC reports
rule multiqc:
    conda:
        "mg-qc"
    output:
        "00_data/fastq/fastqc-R1/multiqc_report.html",
        "00_data/fastq/fastqc-R2/multiqc_report.html"
    group: 2
    priority: 12
    params:
        outfolder1 = "00_data/fastq/fastqc-R1",
        outfolder2 = "00_data/fastq/fastqc-R2"
    log:
        "logs/multiqc/multiqc.log"
    benchmark:
        "benchmarks/multiqc/multiqc.txt"
    shell:
        """
        cd 00_data/fastq/fastqc-R1

        multiqc --export . -f
        cd ..
        cd fastqc-R2
        multiqc --export . -f
        """

# Run fastp
rule fastp:
    conda: 
        "multitrim"
    input:
        r1 = "00_data/fastq/R1/R1_{sample}_R1.fastq",
        r2 = "00_data/fastq/R2/R2_{sample}_R2.fastq"
    output:
        o1 = "01_qc/trimmed_reads/test/{sample}_1.fq",
        o2 = "01_qc/trimmed_reads/test/{sample}_2.fq",
        o3 = "01_qc/trimmed_reads/test/{sample}_test_report.html"
    priority: 11
    log:
        "logs/fastp/{sample}.log"
    benchmark:
        "benchmarks/fastp/{sample}.txt"
    shell:
        """
        fastp \
        -i {input.r1} \
        -o {output.o1} \
        -I {input.r2} \
        -O {output.o2} \
        --detect_adapter_for_pe \
        -g -l 50 -W 4 -M 20 -w 16 \
        --cut_front \
        -h {output.o3}
        """
# Run bbnorm
#rule bbnorm:
#    conda:
#        "mg-norm"
#    input:
#        r1 = "01_qc/trimmed_reads/test/{sample}_1.fq.gz",
#        r2 = "01_qc/trimmed_reads/test/{sample}_2.fq.gz" 
#    output:
#        o1 = "01_qc/{sample}_normalized.fq.gz"
#    priority: 10
#    params:
#        r1 = "01_qc/trimmed_reads/test/{sample}_1.fq.gz",
#        r2 = "01_qc/trimmed_reads/test/{sample}_2.fq.gz"
#    log:
#        "logs/bbnorm/{sample}.log"
#    benchmark:
#        "benchmarks/bbnorm/{sample}.txt"
#    shell:
#        """
#         bbmap/bbnorm.sh in={input.r1} in2={input.r2} out={output.o1} target=100 min=5 interleaved=FALSE -Xmx50g
#        """
# Run megahit
# snakemake will create the output folders since that is the location of the 
# output files we specify. megahit refuses to run if its output folder already
# exists, so because of this, we have to remove the folder snakemake creates
# before we do anything.
# Right now megahit is set to use all the cores and 0.85% of the machine's
# memory. This will probably need to be adjusted when used under other
# situations.
rule megahit:
    conda:
        "mg-assembly"
    input:
        r1 = "01_qc/trimmed_reads/test/{sample}_1.fq",
        r2 = "01_qc/trimmed_reads/test/{sample}_2.fq"
    output:
        o1 = "02_assembly/{sample}/{sample}.contigs.fa"
    priority: 9
    params:
        r1 = "02_assembly/{sample}_R1.fq",
        r2 = "02_assembly/{sample}_R2.fq",
        outfolder = "02_assembly/{sample}",
        prefix = "{sample}"
    threads: 20
    log:
        "logs/megahit/{sample}.log"
    benchmark:
        "benchmarks/megahit/{sample}.txt"
    shell:
        """
        rm -rf {params.outfolder}
        cat {input.r1} > {params.r1}
        cat {input.r2} > {params.r2}
        megahit -1 {params.r1} -2 {params.r2} -m 0.85 -t {threads} \
            --min-contig-len 20 --out-prefix {params.prefix} \
            -o {params.outfolder}
        rm {params.r1} {params.r2}
        """
#build db
rule bbdb:
    conda:
        "mg-binning"
    input:
        seq = "02_assembly/{sample}/{sample}.contigs.fa"
    output:
        o1 = "02_assembly/{sample}.1.bt2",
        o2 = "02_assembly/{sample}.2.bt2",
        o3 = "02_assembly/{sample}.3.bt2",
        o4 = "02_assembly/{sample}.4.bt2",
        o5 = "02_assembly/{sample}.rev.1.bt2",
        o6 = "02_assembly/{sample}.rev.2.bt2"
    priority: 8
    params:
        basename="02_assembly/{sample}"
    threads: 20
    log:
        "logs/bbmap/{sample}.log"
    benchmark:
        "benchmarks/bbmap/{sample}.txt"
    shell:
        """
        bowtie2-build --threads 20 {input.seq} {params.basename}
        """
#map and make sam file
rule bbmap:
    conda:
        "mg-binning"
    input:
        r1 = "01_qc/trimmed_reads/test/{sample}_1.fq",
        r2 = "01_qc/trimmed_reads/test/{sample}_2.fq",
        o1 = "02_assembly/{sample}.1.bt2",
        o2 = "02_assembly/{sample}.2.bt2",
        o3 = "02_assembly/{sample}.3.bt2",
        o4 = "02_assembly/{sample}.4.bt2",
        o5 = "02_assembly/{sample}.rev.1.bt2",
        o6 = "02_assembly/{sample}.rev.2.bt2"
    output:
        o1 = "02_assembly/{sample}/{sample}.sam",
        log = "02_assembly/{sample}.bowtie2.log"
    priority: 7
    params:
        o2 = "02_assembly/{sample}"
    threads: 32
    log:
        "logs/bbmap/{sample}.log"
    benchmark:
        "benchmarks/bbmap/{sample}.txt"
    shell:
        """
        bowtie2 --threads 32 -x {params.o2} -1 {input.r1} \
        -2 {input.r2} -S {output.o1} > {output.log}
        """
rule prodigal:
    conda:
        "mg-assembly"
    input:
        r1 = "02_assembly/{sample}/{sample}.contigs.fa"
    output:
        o1 = "02_assembly/{sample}/prodigal/{sample}_contig_cords.gbk",
        o2 = "02_assembly/{sample}/prodigal/{sample}_contig_orfs.faa",
        o3 = "02_assembly/{sample}/prodigal/{sample}_contig_orfs.fna"
    priority: 6
    threads: 32
    log:
        "logs/prodigal/{sample}.log"
    benchmark:
        "benchmarks/prodigal/{sample}.txt"
    shell:
        """
        prodigal -i {input.r1} -o {output.o1} -a {output.o2} -d {output.o3}
        """
rule prokka:
    conda:
        "mg-assembly2"
    input:
        r1 = "02_assembly/{sample}/{sample}.contigs.fa"
    output:
        o1 = "02_assembly/{sample}/prodigal/{sample}/{sample}.gff",
        o2 = "02_assembly/{sample}/prodigal/{sample}/{sample}.faa"
    priority: 5
    params:
        outfolder = "02_assembly/{sample}/prodigal/{sample}",
        prefix = "{sample}" 
    threads: 32
    log:
        "logs/prokka/{sample}.log"
    benchmark:
        "benchmarks/prokka/{sample}.txt"
    shell:
        """
        prokka {input.r1} --outdir {params.outfolder} --prefix {params.prefix} --force
        """
rule interleave:
    conda:
        "mg-diversity"
    input:
        r1 = "01_qc/trimmed_reads/test/{sample}_1.fq",
        r2 = "01_qc/trimmed_reads/test/{sample}_2.fq",
    output:
        o1 = "01_qc/interleaved/{sample}_interleaved.fq",
    priority: 4
    params:
    threads: 20
    log:
        "logs/bbint/{sample}.log"
    benchmark:
        "benchmarks/bbint/{sample}.txt"
    shell:
        """
       ./bbmap/reformat.sh in1={input.r1} in2={input.r2} out={output.o1} 
        """
rule sourmash:
    conda:
        "mg-diversity"
    input:
        o1 = "01_qc/interleaved/{sample}_interleaved.fq"
    output:
        o2 = "02_assembly/sourmash/tax_out/{sample}_reads.sig",
        o3 = "02_assembly/sourmash/tax_out/{sample}_sourmash_gather_out.csv",
    priority: 3
    params:
        outfolder2 = "02_assembly/sourmash/tax_out/{sample}",
        db = "./dbs/gtdb-rs202.genomic-reps.k31.zip"
    threads: 20
    log:
        "logs/sourmash/{sample}.log"
    benchmark:
        "benchmarks/sourmash/{sample}.txt"
    shell:
        """
        sourmash sketch dna {input.o1} -o {output.o2} 
        sourmash gather {output.o2} {params.db} -o {output.o3} --ignore-abundance 
        sourmash tax metagenome -g {output.o3} -t ./dbs/gtdb-rs202.taxonomy.v2.csv -o {params.outfolder2} --output-format csv_summary --force
        sourmash tax metagenome -g {output.o3} -t ./dbs/gtdb-rs202.taxonomy.v2.csv -o {params.outfolder2} --output-format krona --rank family --force
        """
rule maxbin2:
    conda:
        "mg-binning2"
    input:
        r1 = "02_assembly/{sample}/{sample}.contigs.fa",
        r2 = "01_qc/trimmed_reads/test/{sample}_1.fq",
        r3 = "01_qc/trimmed_reads/test/{sample}_2.fq"
    output:
        o2 = "02_assembly/{sample}_MaxBin.abundance"
    priority: 4
    params:
        outfolder = "02_assembly/{sample}_MaxBin"
    threads: 20
    log:
        "logs/maxbin/{sample}.log"
    benchmark:
        "benchmarks/maxbin/{sample}.txt"
    shell:
        """
        run_MaxBin.pl -contig {input.r1} -min_contig_length 100 \
        -reads {input.r2} -reads2 {input.r3} \
        -out {params.outfolder} -thread 20
        """

rule checkm:
    conda:
        "checkm"
    input:
        r1 = "00_data/fastq/fastqc-R1/multiqc_report.html"
    output:
        o2 = "02_assembly/checkm/results/checkm.log"    
    params:
        outfolder = "02_assembly/checkm",
        outfolder2 = "02_assembly/checkm/results"
    log:
        "logs/checkm/checkm.log"
    benchmark:
        "benchmarks/checkm/checkm.txt"
    shell:
        """
        export CHECKM_DATA_PATH=./dbs/
        cp 02_assembly/*/*.contigs.fa 02_assembly/checkm
        test -f {output.o2} && 2>&1 || checkm lineage_wf -x fa {params.outfolder} {params.outfolder2} >output.log
        """
rule dRep:
    conda:
        "mg-binning3"
    input:
        r1 = "README.md"
    output:
        o1 = "02_assembly/dRep_out/log/logger.log"
    priority: 1
    params:
        infolder = "02_assembly/dRep_data",
        outfolder = "02_assembly/dRep_out"
    threads: 20
    log:
        "logs/dRep/dRep.log"
    benchmark:
        "benchmarks/dRep/dRep.txt"
    shell:
        """
        if [ -d "{params.infolder}" ]; then
            rm -rf "{params.infolder}"
        fi
        if [ -d "{params.outfolder}" ]; then
            rm -rf "{params.outfolder}"
        fi
        mkdir -p "{params.infolder}"
        mkdir -p "{params.outfolder}"
        cp 02_assembly/*.fasta "{params.infolder}"
        test -f "{output.o1}" && 2>&1 || dRep dereplicate "{params.outfolder}" -g 02_assembly/dRep_data/*.fasta --ignoreGenomeQuality --SkipSecondary
        """


rule GTDBtk:
    conda:
        "mg-binning3"
    input:
        r1 = "logs/dRep/dRep.log"
    output:
        o2 = "03_assignment/GTDBtk/gtdbtk.log",
        o3 = "03_assignment/GTDBtk/mashoutput.msh"
    params: 
        o1 = directory("03_assignment/GTDBtk"),
        i1 = "02_assembly/dRep_data/"
    threads: 20
    log:
        "logs/GTDBtk/gtdb.log"
    benchmark:
        "benchmarks/GTDBtk/bm.txt"
    shell:
        """
        mkdir -p 03_assignment/
        mkdir -p 03_assignment/GTDBtk
        gtdbtk classify_wf --mash_db 03_assignment/GTDBtk/mashoutput.msh --genome_dir {params.i1} --out_dir {params.o1} --extension fasta
        """


