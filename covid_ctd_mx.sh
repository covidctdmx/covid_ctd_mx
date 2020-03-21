#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"

#URL original
#https://www.gob.mx/salud/documentos/nuevo-coronavirus-2019-ncov-comunicado-tecnico-diario
#https://www.gob.mx/salud/documentos/coronavirus-covid-19-comunicado-tecnico-diario-238449
#https://www.gob.mx/salud/archivo/documentos?utf8=%E2%9C%93&idiom=es&style=list&order=desc&filter_id=395&filter_origin=archive&tags=&category=

URL_BASE="https://www.gob.mx"
URL_SDOC="https://www.gob.mx/salud/archivo/documentos"
STR_CTD="comunicado-tecnico-diario"
RES_FILE="recursos/url_ctd.txt"
DOC_PATH="originales/"
HTML_NME="covid.html"

URLS_CTD=()
DOCS=()
DOCS_FILE=()

#DAT_QURY=$(date +"%Y%m%d_%H%M%S")

function getUrlsCTD () {
    URLS_CTD=($(
        echo -e "${URL_BASE}$(
            curl -s "${URL_SDOC}" |\
            sed -e "s@  @\n@g" |\
            grep -e "${STR_CTD}" |\
            sed -e 's@\\"@"@g' |\
            sed -e "s@.*<a class=\"small-link\" href=\"\(.*\)\" target=\".*@\1@g"
            )"\
        ))

    checkUrlFile "${RES_FILE}"
    echo -e "${DAT_QURY} ${URLS_CTD[*]}" >> "${RES_FILE}"
    
    for URL_CTD in ${URLS_CTD[*]};do
        cleanUrlFile "${URL_CTD}" "${RES_FILE}"
    done
}

function checkUrlFile(){
    FILE="$1"
    if [[ ! -f "${FILE}" ]];then
        touch "${FILE}"
    fi
}

function checkDirExist(){
    DIR="$1"
    if [[ ! -d "${DIR}" ]];then
        mkdir "${DIR}"
    fi
}

function cleanUrlFile(){
    URL_STRN="$(echo -e "$1" | sed -e "s@\/@\\\/@g")"
    sed -i "/$(echo "${URL_STRN}")/d" $2
    echo -e "${DAT_QURY} $1" >> "$2"
}

function downloadFilesFromCTD(){
        DOCS=($(\
            curl -s $1 |\
            grep -e "<a href=\"/cms" |\
            sed -e "s@.*<a href=\"/cms\(.*\)\"@${URL_BASE}/cms\1@g"\
        ))

        checkDirExist "${DOC_PATH}"
        
        for DOC in ${DOCS[*]};do
            DOC_BNME=$(basename $(echo -e "${DOC}"))
            if [[ ${DOC} = *ecnico*pdf ]];then
                DOC_NME2=$(
                    echo "${DOC_BNME}" |\
                    sed -e "s@.*_\(.*\)\..*@\1@g" |\
                    tr -d "." |\
                    sed -e "s@\(.*\)@\1_tec@g"\
                )
            elif [[ ${DOC} = *ositivos*pdf ]];then
                DOC_NME2=$(
                    echo "${DOC_BNME}" |\
                    sed -e "s@.*_\(.*\)\..*@\1@g" |\
                    tr -d "." |\
                    sed -e "s@\(.*\)@\1_pos@g"\
                )
            elif [[ ${DOC} = *ospechosos*pdf ]];then
                DOC_NME2=$(
                    echo "${DOC_BNME}" |\
                    sed -e "s@.*_\(.*\)\..*@\1@g" |\
                    tr -d "." |\
                    sed -e "s@\(.*\)@\1_sos@g"\
                )
            else
                DOC_NME2=$(echo -e "${DOC_BNME}")
            fi

            wget -q "${DOC}" -O "${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf"

            DOCS_FILE=($(ls originales | grep -e "${DOC_NME2}"))
            FLAG_FILE_EXIST="0"
            DOCS_FILE_LEN=${#DOCS_FILE[*]}
            
            if [[ ${DOCS_FILE_LEN} -gt 1 ]];then
                for DOC_FILE in ${DOCS_FILE[*]};do
                    if [[ -f "${DOC_PATH}${DOC_FILE}" ]] && [[ "${DOC_PATH}${DOC_FILE}" != "${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf" ]];then
                        DOC_MD5O=$(md5sum "${DOC_PATH}${DOC_FILE}" | sed -e "s@\(.*\)  .*@\1@g")
                        DOC_MD5N=$(md5sum "${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf" | sed -e "s@\(.*\)  .*@\1@g")
                        if [[ "${DOC_MD5O}" = "${DOC_MD5N}" ]];then
                            FLAG_FILE_EXIST="1"
#                        else
#                            echo -e "1Se descargo archivo "$DOC_PATH$DOC_NME2""_""${DAT_QURY}.pdf""
                        fi
                    fi
                done

                if [[ "${FLAG_FILE_EXIST}" = "1" ]];then
                    rm -rf "$DOC_PATH$DOC_NME2""_""${DAT_QURY}.pdf"
                else
                    echo -e "2Se descargo archivo "$DOC_PATH$DOC_NME2""_""${DAT_QURY}.pdf""
                fi
            else
                echo -e "3Se descargo archivo "$DOC_PATH$DOC_NME2""_""${DAT_QURY}.pdf""
            fi
        done
}

function checkUrlsInFile(){
    if [[ "$(wc -l "${RES_FILE}" | sed -e "s@\(.*\) .*@\1@g")" == "1" ]];then
        URL_DOCS="$(tail -n 1 ${RES_FILE} | sed -e "s@.*_.* https:@https:@g")"
    else
        printf "Existe mas de una url en el archivo de URLS\n\n"
        cat "${RES_FILE}"
        printf "\nEscribe la url que contiene a los archivos:\n"
        read -r URL_DOCS
    fi
}

function convPdftoCsv(){
    PDFS_POS_SOS=($(ls ${DOC_PATH} | grep -e "sos\|pos"))
    for PDF_POS_SOS in ${PDFS_POS_SOS[*]};do
        EXT_NAME="${PDF_POS_SOS##*.}"
        FILE_NAME="${PDF_POS_SOS%.*}"
        EXT_CSV=".csv"

        if [[ ! -f "${DOC_PATH}${FILE_NAME}${EXT_CSV}" ]];then
            pdftops "${DOC_PATH}${FILE_NAME}.${EXT_NAME}"
            touch "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            echo -e "# Caso,Estado,Sexo,Fecha de Inicio de sintomas,Edad,Identificacion de COVID-19 por RT-PCR en tiempo real,Procedencia,Fecha del llegada a Mexico" >> "${DOC_PATH}${FILE_NAME}${EXT_CSV}"

            if [[ $(echo -e "${FILE_NAME}" | grep -e "pos") ]];then
                ps2ascii "${DOC_PATH}${FILE_NAME}.ps" |\
                    sed '/^$/d' |\
                    sed $"s@[^[:print:]\t]@@g" |\
                    sed -e "s@'\|~\|,@@g" |\
                    sed -e "s@  @,@g" |\
                    grep -e ".*,.*,.*,.*,.*,.*,.*,.*" |\
                    sed -n '1 !p' |\
                    sed -e "s@\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),@\1,\2,\3,\4,\5,\6,\7,\8@g" >> "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
                rm -rf "${DOC_PATH}${FILE_NAME}.ps"
                echo -e "Se creo archivo ${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            elif [[ $(echo -e "${FILE_NAME}" | grep -e "sos") ]];then
                ps2ascii "${DOC_PATH}${FILE_NAME}.ps" |\
                    sed '/^$/d' |\
                    sed $"s@[^[:print:]\t]@@g" |\
                    sed -e "s@'\|~\|,@@g" |\
                    sed -e "s@  @,@g" |\
                    grep -e ".*,.*,.*,.*,.*,.*,.*,.*" |\
                    sed -e "s@\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),@\1,\2,\3,\4,\5,\6,\7,\8@g" >> "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
                rm -rf "${DOC_PATH}${FILE_NAME}.ps"
                echo -e "Se creo archivo ${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            fi
        fi
    done
}

function main (){
#Revisa cuantas urls contienen la cadena STR_CTD="comunicado-tecnico-diario" 
while true;do
    DAT_QURY="$(date +"%Y%m%d_%H%M%S")"
    echo -e "${DAT_QURY} Se muestra el contenido del archivo que contiene las urls del Comunicado Tecnico Diario"
    if [[ "$(curl -s -I ${URL_SDOC} | sed -n '1 p' | sed $"s@[^[:print:]\t]@@g")" = "HTTP/1.1 200 OK" ]];then
        echo -e "Revisando si la URL del CTD cambio"
        getUrlsCTD
    else
        echo -e "El servidor esta en mantenimiento, se ocupa la ultima URL del archivo"
    fi
    cat "${RES_FILE}"
    checkUrlsInFile
    downloadFilesFromCTD "${URL_DOCS}"        
    convPdftoCsv
    echo -e "Esperando para hacer una nueva consulta\n\n"
    sleep 600
done
}

main $@
