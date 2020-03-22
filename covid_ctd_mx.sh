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

#URL original
#https://www.gob.mx/salud/documentos/nuevo-coronavirus-2019-ncov-comunicado-tecnico-diario
#https://www.gob.mx/salud/documentos/coronavirus-covid-19-comunicado-tecnico-diario-238449
#https://www.gob.mx/salud/archivo/documentos?utf8=%E2%9C%93&idiom=es&style=list&order=desc&filter_id=395&filter_origin=archive&tags=&category=

URL_BASE="https://www.gob.mx"
URL_SDOC="https://www.gob.mx/salud/archivo/documentos"
STR_CTD="comunicado-tecnico-diario"
RES_PATH="recursos/"
RES_FILE="url_ctd.txt"
DOC_PATH="originales/"
HTML_NME="covid.html"

URLS_CTD=()
DOCS=()
DOCS_FILE=()

function validateUrlCTD(){
    local RES_WEB="$(curl -s -I ${URL_SDOC} | sed -n '1 p' | sed $"s@[^[:print:]\t]@@g" | grep -e "200" 1>/dev/null;echo $?)"

    if [[ "${RES_WEB}" = "0" ]];then
        getUrlsCTD
        getLastUrlsInFile
    else
#Si la primera vez que se ejecuta el script la URL https://www.gob.mx/salud/archivo/documentos no está disponible dará un error
        local URL_DOCS="$(tail -n 1 "${RES_PATH}${RES_FILE}" | sed -e "s@.*http@http@g")"
    fi
    echo -e "Se buscan archivos en la URL:\n${URL_DOCS}"

}
function getUrlsCTD() {
    URLS_CTD=($(
        echo -e "${URL_BASE}$(
            curl -s "${URL_SDOC}" |\
            sed -e "s@  @\n@g" |\
            grep -e "${STR_CTD}" |\
            sed -e 's@\\"@"@g' |\
            sed -e "s@.*<a class=\"small-link\" href=\"\(.*\)\" target=\".*@\1@g"
            )"\
        ))
    checkUrlFile "${RES_PATH}" "${RES_FILE}"
    
    for URL_CTD in ${URLS_CTD[*]};do
        updateUrlInFile "${URL_CTD}"
    done
}

function checkUrlFile(){
    local DIR="$1"
    local FILE="$2"

    if [[ ! -f "${DIR}${FILE}" ]];then
        checkDirExist "${DIR}"
        echo "" > "${DIR}${FILE}"
    fi
}

function checkDirExist(){
    local DIR="$1"

    if [[ ! -d "${DIR}" ]];then
        mkdir -p "${DIR}"
    fi
}

function updateUrlInFile(){
    local URL="$1"
    local URL_EXIST="$(cat "${RES_PATH}${RES_FILE}" | grep -e "${URL}" 1>/dev/null; echo $?)"

    if [[ "${URL_EXIST}" != "0" ]];then
        echo -e "${DAT_QURY} ${URL}" >> "${RES_PATH}${RES_FILE}"
    fi
}

#Puede causar error si la pagina principal del CTD tiene mas de un enlace a los archivos PDF
function getLastUrlsInFile(){
    local COUNT_LINES="$(wc -l "${RES_PATH}${RES_FILE}" | sed -e "s@\(.*\) .*@\1@g")"
    URL_DOCS="$(tail -n 1 "${RES_PATH}${RES_FILE}" | sed -e "s@.*http@http@g")"

    if [[ "${COUNT_LINES}" != "1" ]];then
        echo -e "\nExiste mas de una URL en el archivo de URLS"
        cat "${RES_PATH}${RES_FILE}" | sed -e "s@.*http@http@g"
        echo -e "\nSe usa la ultima de la lista:\n${URL_DOCS}"
    fi
}


function dwnloadFilesFromCTD(){
        checkDirExist "${DOC_PATH}"
	local DOC_NME2=""
        local DOCS=($(\
            curl -s ${URL_DOCS} |\
            grep -e "<a href=\"/cms" |\
            sed -e "s@.*<a href=\"/cms\(.*\)\"@${URL_BASE}/cms\1@g"\
        ))
        
        for DOC in ${DOCS[*]};do
            local DOC_BNME=$(basename $(echo -e "${DOC}"))
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
                    if [[ "${DOC_PATH}${DOC_FILE}" != "${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf" ]];then
                        DOC_MD5O=$(md5sum "${DOC_PATH}${DOC_FILE}" | sed -e "s@\(.*\)  .*@\1@g")
                        DOC_MD5N=$(md5sum "${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf" | sed -e "s@\(.*\)  .*@\1@g")
                        if [[ "${DOC_MD5O}" = "${DOC_MD5N}" ]];then
                            FLAG_FILE_EXIST="1"
                        fi
                    fi
                done

                if [[ "${FLAG_FILE_EXIST}" = "1" ]];then
                    rm -rf "${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf"
                    echo -e "No se descarga ${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf el archivo ya existe"
                else
                    echo -e "2Se descargo archivo "${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf""
                fi
            else
                echo -e "3Se descargo archivo "${DOC_PATH}${DOC_NME2}""_""${DAT_QURY}.pdf""
            fi
        done
}

function convPdftoCsv(){
    local PDFS_POS_SOS=($(ls ${DOC_PATH} | grep -e ".*pos.*.pdf\|.*sos.*.pdf"))
    for PDF_POS_SOS in ${PDFS_POS_SOS[*]};do
        local FILE_NAME="${PDF_POS_SOS%.*}"
        local EXT_NAME="${PDF_POS_SOS##*.}"
        local EXT_CSV=".csv"

	if [[ ! -f "${DOC_PATH}${FILE_NAME}${EXT_CSV}" ]];then
            echo "" > "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            echo -e "# Caso,Estado,Sexo,Edad,Fecha de Inicio de sintomas,Identificacion de COVID-19 por RT-PCR en tiempo real,Procedencia,Fecha del llegada a Mexico" >> "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            sed -i '/^$/d' "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            PDF_VERSION=$(file "${DOC_PATH}${FILE_NAME}.${EXT_NAME}" | sed -e "s@.*PDF document, version @@g")

	    if [[ "${PDF_VERSION}" = "1.5" ]];then
	        pdftops "${DOC_PATH}${FILE_NAME}.${EXT_NAME}"
                TO_ASCII_FILE_EXT="ps"
            elif [[ "${PDF_VERSION}" = "1.3" ]];then
                TO_ASCII_FILE_EXT="pdf"
            else
		echo -e "La version del PDF es ${PDF_VERSION}, se intenta convertir"
                pdftops "${DOC_PATH}${FILE_NAME}.${EXT_NAME}"
                TO_ASCII_FILE_EXT="ps"
	    fi

            if [[ $(echo -e "${FILE_NAME}" | grep -e "pos") ]];then
                ps2ascii "${DOC_PATH}${FILE_NAME}.${TO_ASCII_FILE_EXT}" |\
                sed '/^$/d' |\
                sed $"s@[^[:print:]\t]@@g" |\
                sed -e "s@'\|~\|,\|\t@@g" |\
                sed 's/[[:blank:]]/,/g' |\
                sed 's/\([,]\{2\}\)/#/g' |\
                sed -e "s@#,@#@g" |\
                sed -e "s@#######w@#@g" |\
                sed -e "s@######@#@g" |\
                sed -e "s@####@#@g" |\
                sed -e "s@###@#@g" |\
                sed -e "s@##@#@g" |\
                sed -e "s@,\$@@g" |\
                tr "," " " |\
                tr "#" "," |\
                sed -e "s@^,@@g" |\
                grep -e ".*,.*,.*,.*,.*,.*,.*,.*" |\
		sed -n '1 !p' >> "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
                rm -rf "${DOC_PATH}${FILE_NAME}.ps"
		echo -e "Se creo archivo ${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            elif [[ $(echo -e "${FILE_NAME}" | grep -e "sos") ]];then
                ps2ascii "${DOC_PATH}${FILE_NAME}.${TO_ASCII_FILE_EXT}" |\
                sed '/^$/d' |\
                sed $"s@[^[:print:]\t]@@g" |\
                sed -e "s@'\|~\|,\|\t@@g" |\
                sed 's/[[:blank:]]/,/g' |\
                sed 's/\([,]\{2\}\)/#/g' |\
                sed -e "s@#,@#@g" |\
                sed -e "s@#######w@#@g" |\
                sed -e "s@######@#@g" |\
                sed -e "s@####@#@g" |\
                sed -e "s@###@#@g" |\
                sed -e "s@##@#@g" |\
                sed -e "s@,\$@@g" |\
                tr "," " " |\
                tr "#" "," |\
                sed -e "s@^,@@g" |\
		sed -e "s@,SUR,@,BAJA CALIFORNIA SUR,@g" |\
                grep -e ".*,.*,.*,.*,.*,.*,.*,.*" |\
	        sed -n '1 !p' >> "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
                rm -rf "${DOC_PATH}${FILE_NAME}.ps"
		echo -e "Se creo archivo ${DOC_PATH}${FILE_NAME}${EXT_CSV}"

            fi
	fi
#	cat "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
#	read -r
    done
}

function invCountNewQury(){
    echo -e "Esperando para hacer una nueva consulta en:"
    for sec in {15..1}; do
        echo -e " ${sec} minutos"
        sleep 60
    done
    echo -e "\n"
}


function main (){
while true;do
#date +"%Y/%m/%d %H:%M:%S.%4N"
    DAT_QURY="$(date +"%Y%m%d_%H%M%S")"
    echo -e "Inicio de consulta: ${DAT_QURY}"
    validateUrlCTD
    dwnloadFilesFromCTD
    convPdftoCsv
    invCountNewQury
done
}

main $@
