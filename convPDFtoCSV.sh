#!/usr/bin/env bash
clear

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"

function pdfToCsv(){
    DOCS=($(ls "$1"))
    echo -e "xxxx ${#DOCS[*]}"
    for DOC in ${DOCS[*]};do
        local DOC_BNME="${DOC}"
        if [[ ${DOC} = *ecnico*pdf* ]];then
            DOC_NME2=$(
                echo "${DOC_BNME}" |\
                sed -e "s@.*_\(.*\)\..*@\1@g" |\
                tr -d "." |\
                sed -e "s@\(.*\)@\1_tec@g"\
                )
        elif [[ ${DOC} = *ositivos*pdf* ]];then
            DOC_NME2=$(
                echo "${DOC_BNME}" |\
                sed -e "s@.*_\(.*\)\..*@\1@g" |\
                tr -d "." |\
                sed -e "s@\(.*\)@\1_pos@g"\
                )
        elif [[ ${DOC} = *ospechosos*pdf* ]];then
            DOC_NME2=$(
                echo "${DOC_BNME}" |\
                sed -e "s@.*_\(.*\)\..*@\1@g" |\
                tr -d "." |\
                sed -e "s@\(.*\)@\1_sos@g"\
                )
        else
            DOC_NME2="$(echo -e "${DOC_BNME}")"
        fi
    cp -v "$1${DOC_BNME}" "$1${DOC_NME2}""_""$DAT_QURY.pdf"
    done	    
}

function main(){
    DAT_QURY="$(date +"%Y%m%d_%H%M%S")"
    pdfToCsv "$1"
}


main $@
