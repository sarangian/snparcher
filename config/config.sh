#!/bin/bash

# Define colors for output
color_cyan="\033[0;36m"  # Cyan color
color_ylow="\033[0;33m"
color_lgrn="\033[0;32m"
color_reset="\033[0m"    # Reset color to default

# Function to print the directory tree inside a box
print_tree_in_box() {
    local content="$1"
    
    # Calculate width of the box
    local width=$(echo -n "$content" | awk '{print length($0)}' | sort -nr | head -n1)
    # Add padding for borders
    width=$((width + 4))
    
    # Print top border
    printf "+%${width}s+\n" "" | tr " " "-"
    
    # Print content with left and right borders
    echo -e " ${content} "
    
    # Print bottom border
    printf "+%${width}s+\n" "" | tr " " "-"
}

# Construct the directory structure
tree_structure=$(cat <<EOF
${color_cyan}Deliverables${color_reset}
${color_ylow}|-- config${color_reset}
${color_cyan}|   |-- config.yaml${color_reset}
${color_cyan}|   |-- resources.yaml${color_reset}
${color_cyan}|   |-- samples.csv${color_reset}
${color_ylow}|-- data${color_reset}
${color_lgrn}    |-- symlink${color_reset}
${color_cyan}    |   |-- my_sample1_1.fastq.gz${color_reset}
${color_cyan}    |   |-- my_sample1_2.fastq.gz${color_reset}
${color_cyan}    |   |-- my_sample2_1.fastq.gz${color_reset}
${color_cyan}    |   |-- my_sample2_2.fastq.gz${color_reset}
${color_cyan}    |   |-- my_sample3_1.fastq.gz${color_reset}
${color_cyan}    |   |-- my_sample3_2.fastq.gz${color_reset}
${color_cyan}    |   |-- my_sample4_1.fastq.gz${color_reset}
${color_cyan}    |   |-- my_sample4_2.fastq.gz${color_reset}
${color_lgrn}    |-- reference${color_reset}
${color_cyan}        |-- demo_genome.fna.gz${color_reset}
EOF
)

# Print the tree structure inside a box
print_tree_in_box "$tree_structure"
echo -n "NOTE: THE SCRIPT MUST BE EXECUTED AT SSD INSIDE NCGM-XXXX FOLDER"
echo
echo
echo -n "Enter the Deliverables with sub-folder data containing symlink and reference: "
read DeliverablesDIR

echo
echo

ConfigDIR=${DeliverablesDIR}/config
mkdir -p ${ConfigDIR}
######################################################
#     CHECK SYMLINK FOLDER                           #
######################################################

# List of FASTQ allowed extensions
FQEXTENSIONS=("fq.gz" "fastq.gz")

FASTQ_DIR=${DeliverablesDIR}/data/symlink
if [ ! -d "$FASTQ_DIR" ]; then
    echo "Error: Directory '$FASTQ_DIR' not found. Please create the symlink Directory with symbolic links"
    exit 1
fi

# Flag to indicate if any file with the required extension is found
found=false

# Iterate over each allowed extension
for ext in "${FQEXTENSIONS[@]}"; do
    # Check if files with the current extension exist in the folder
    if ls "$FASTQ_DIR"/*."$ext" &> /dev/null; then
        found=true
        break
    fi
done

# Check the result and exit with appropriate message
if [ "$found" = true ]; then
    echo "File check passed. FASTQ files found."
else
    echo "Error: No FASTQ files found in the Deliverables/data/symlink folder."
    exit 1
fi


####################################################################
#      CHECK REFERENCE FOLDER                                      #
####################################################################

REF_FOLDER_PATH=${DeliverablesDIR}/data/reference

# List of allowed extensions
EXTENSIONS=("fna.gz" "fna" "fa" "fasta" "fasta.gz")

# Check if the folder exists
if [ ! -d "$REF_FOLDER_PATH" ]; then
    echo "Error: The folder '$REF_FOLDER_PATH' does not exist."
    exit 1
fi

# Flag to indicate if any file with the required extension is found
found=false

# Iterate over each allowed extension
for ext in "${EXTENSIONS[@]}"; do
    # Check if files with the current extension exist in the folder
    if ls "$REF_FOLDER_PATH"/*."$ext" &> /dev/null; then
        found=true
        break
    fi
done

# Check the result and exit with appropriate message
if [ "$found" = true ]; then
    echo "File check passed. At least one valid file found."
else
    echo "Error: No genome files with extensions .fna.gz, .fna, .fa, .fasta, or .fasta.gz found in the Deliverables/reference folder."
    exit 1
fi

##########################################################################################
# Get the Genome Name                                                                    #
##########################################################################################
# Loop through each file in the directory
for refFilePath in ${REF_FOLDER_PATH}/*; do
    # Check if the file has a matching extension
    if [[ ${refFilePath} =~ \.(fna|fna.gz|fa|fa.gz|fasta|fasta.gz)$ ]]; then
        # Get the base name without the extension(s)
        refGenome=$(basename ${refFilePath} | sed -E 's/\.(fna|fna.gz|fa|fa.gz|fasta|fasta.gz)$//')
        refGenomeFile=$(basename ${refFilePath})
        # Output the base name
        echo "Genome Name: " $refGenome
        refPath="data/reference"/${refGenomeFile}
        echo "Genome File relative path: $refPath"
    fi
done


Run=NaN
BioProject=NaN
##########################################################################################
cd ${ConfigDIR}
wget https://raw.githubusercontent.com/sarangian/snparcher/master/.test/ecoli/config/config.yaml
mv config.yaml config.yaml.template
wget https://raw.githubusercontent.com/sarangian/snparcher/master/.test/ecoli/config/resources.yaml
mv resources.yaml resources.yaml.template

############################################################################################
#                         CREATE SAMPLE SHEET                                              #
############################################################################################

echo "BioSample,LibraryName,refGenome,refPath,Run,BioProject,fq1,fq2" > ${ConfigDIR}/samples.csv
for i in `ls ${FASTQ_DIR} | grep -E "_1|R1" `;do echo $i;done
echo -n "Please look into the read names and provide the extension after sample name Example: _R1_001.fastq.gz: "
read R1_extn

for i in `ls ${FASTQ_DIR} | grep -E '_2|R2'`;do echo $i;done
echo -n "Please look into the read names and provide the extension after sample name Example: _R2_001.fastq.gz: "
read R2_extn
Run=1
for i in `ls ${FASTQ_DIR} | grep ${R1_extn}`;do 
BioSample=`basename $i ${R1_extn}`
LibraryName=lib_${BioSample}
fq1="data/symlink/"${BioSample}${R1_extn}
fq2="data/symlink/"${BioSample}${R2_extn}
echo "${BioSample},${LibraryName},${refGenome},${refPath},${Run},${BioProject},${fq1},${fq2}" >> ${ConfigDIR}/samples.csv
Run=$((Run+1))
done

echo
echo
echo "Sample Sheet Path: " ${ConfigDIR}/samples.csv
echo
echo "Project Config Template Path: " ${ConfigDIR}/config.yaml.template

echo
echo "Project Resources Template Path: " ${ConfigDIR}/resources.yaml.template

echo "Please rename the config.yaml.template and resources.yaml.template to config.yaml and resources.yaml."
echo "Please update the values in config and resourse file according to your need"
echo
echo "example command to run snparcher: "
echo "singularirty exec <snparcher sif path> snakemake -s /opt/snparcher/workflow/Snakefile -d ${DeliverablesDIR} --cores <CPU NO> --set-resources bam2gvcf:mem_mb_reduced=5000 --set-resources gvcf2DB:mem_mb_reduced=5000 --set-resources DB2vcf:mem_mb_reduced=5000"
