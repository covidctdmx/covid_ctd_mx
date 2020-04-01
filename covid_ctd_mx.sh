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
RES_PATH="recursos/"
RES_FILE="url_ctd.txt"
DOC_PATH="originales/"
HTML_NME="covid.html"
MERGE_PATH="merge/"

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
                sed -e "s@#######@#@g" |\
                sed -e "s@######@#@g" |\
                sed -e "s@####@#@g" |\
                sed -e "s@###@#@g" |\
                sed -e "s@##@#@g" |\
                sed -e "s@,\$@@g" |\
                tr "," " " |\
                tr "#" "," |\
                sed -e "s@^,@@g" |\
                grep -e "^\(.*,.*,.*,.*,.*,.*,.*,.*\)$\|^\(.*,.*,.*,.*,.*,.*,.*\)$\|^\(.*,.*,.*,.*,.*,.*,.*,.*\)$\|Estados" |\
                grep -v "^Estados$\|^,Estados$" |\
		sed -n '1 !p' >> "${DOC_PATH}${FILE_NAME}.tmp"
            elif [[ $(echo -e "${FILE_NAME}" | grep -e "sos") ]];then
                ps2ascii "${DOC_PATH}${FILE_NAME}.${TO_ASCII_FILE_EXT}" |\
                sed '/^$/d' |\
                sed $"s@[^[:print:]\t]@@g" |\
                sed -e "s@'\|~\|,\|\t@@g" |\
                sed 's/[[:blank:]]/,/g' |\
                sed 's/\([,]\{2\}\)/#/g' |\
                sed -e "s@#,@#@g" |\
                sed -e "s@#######@#@g" |\
                sed -e "s@######@#@g" |\
                sed -e "s@####@#@g" |\
                sed -e "s@###@#@g" |\
                sed -e "s@##@#@g" |\
                sed -e "s@,\$@@g" |\
                tr "," " " |\
                tr "#" "," |\
                sed -e "s@^,@@g" |\
                grep -e "^\(.*,.*,.*,.*,.*,.*,.*,.*\)$\|^\(.*,.*,.*,.*,.*,.*,.*\)$\|Estados" |\
                grep -v "^Estados$\|^,Estados$" |\
	        sed -n '1 !p' >> "${DOC_PATH}${FILE_NAME}.tmp"

            fi

            COUNT_LINES=1
	    COUNT=0
            LINE=""
	    cp "${DOC_PATH}${FILE_NAME}.tmp" "${DOC_PATH}${FILE_NAME}.tmp1"
            while read LINE;do
                if [[ $(echo -e "${LINE}" | grep -e "^.*,Estados$") ]];then
                    STATE=$(echo -e "${LINE}" | sed -e "s@^\(.*\),Estados\$@\1@g")
                    COUNT2=$(( ${COUNT_LINES} + 1 ))
                    sed  -i "${COUNT2} s@\(.*\),\(.*,.*,.*,.*,.*,.*\)@\1,${STATE},\2@" "${DOC_PATH}${FILE_NAME}.tmp1"
                fi
                COUNT_LINES=$(( ${COUNT_LINES} + 1 ))
            done < "${DOC_PATH}${FILE_NAME}.tmp"

            cat "${DOC_PATH}${FILE_NAME}.tmp1" |\
            grep -v ".*,Estados$" |\
            sed -e "s@,SUR,\(.*\)BAJA CALIFORNIA,@,BAJA CALIFORNIA SUR,\1@g" |\
            sed -e "s@,SUR,@,BAJA CALIFORNIA SUR,@g" |\
            sed -e "s@,Unidos,@,Estados Unidos,@g" > "${DOC_PATH}${FILE_NAME}${EXT_CSV}"

            rm -rf "${DOC_PATH}${FILE_NAME}.tmp" "${DOC_PATH}${FILE_NAME}.tmp1"

            COMMA_COUNT=$(sed -n "1 p" ${DOC_PATH}${FILE_NAME}${EXT_CSV} | grep -o "," | wc -l)

            if [[ "${COMMA_COUNT}" = "8" ]];then
                sed -i "1i # Caso,Estado,Localidad,Sexo,Edad,Fecha de Inicio de sintomas,Identificacion de COVID-19 por RT-PCR en tiempo real,Procedencia,Fecha del llegada a Mexico" "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            else
                sed -i "1i # Caso,Estado,Sexo,Edad,Fecha de Inicio de sintomas,Identificacion de COVID-19 por RT-PCR en tiempo real,Procedencia,Fecha del llegada a Mexico"  "${DOC_PATH}${FILE_NAME}${EXT_CSV}"
            fi

	    rm -rf "${DOC_PATH}${FILE_NAME}.ps"
            sed -i "1 s@^@\xef\xbb\xbf@g" ${DOC_PATH}${FILE_NAME}${EXT_CSV}
            echo -e "Se creo archivo ${DOC_PATH}${FILE_NAME}${EXT_CSV}"
	fi
    done
}

function invCountNewQury(){
    echo -e "Esperando para hacer una nueva consulta en:"
    for sec in {10..1}; do
        echo -e " ${sec} minutos"
        sleep 60
    done
    echo -e "\n"
}

function makeCsvExt(){
    checkDirExist "${MERGE_PATH}pos"
    checkDirExist "${MERGE_PATH}sos"

    for TYPE_FILE in "pos" "sos";do
	FILES_CSV=($(ls "${DOC_PATH}" | grep -e ".*${TYPE_FILE}.*.csv"))

        for FILE_CSV in ${FILES_CSV[*]};do
            FILE_CSV_EXT_EXIST=$(ls "${MERGE_PATH}${TYPE_FILE}/" | grep "${FILE_CSV}" 1>/dev/null; echo $?)

	    if [[ "${FILE_CSV_EXT_EXIST}" = "1" ]];then
		FILE_CSV_LEN=$(wc -l "${DOC_PATH}${FILE_CSV}" | sed -e "s@\(.*\) ${DOC_PATH}${FILE_CSV}@\1@g")
                cp "${DOC_PATH}${FILE_CSV}" "${MERGE_PATH}${TYPE_FILE}/"
		FILE_CSV_DATE=$(echo -e "${FILE_CSV}" | sed -e "s@^\([0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)_.*_.*_.*.csv@\3/\2/\1@g")
                COMMA_COUNT=$(sed -n "1 p" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}" | grep -o "," | wc -l)

		time for LINE_CSV in $(seq 2 1 ${FILE_CSV_LEN});do
                    if [[ "${COMMA_COUNT}" = "7" ]];then
                        LINE=$(sed -n "${LINE_CSV} p" "${DOC_PATH}${FILE_CSV}")
                        LINE_COL_STATE=$(echo -e "${LINE}" | sed -e "s@^.*,\(.*\),.*,.*,.*,.*,.*,.*\$@\1@g")
                        LINE_COL_DATE_SYMP=$(echo -e "${LINE}" | sed -e "s@^.*,.*,.*,.*,\(.*\),.*,.*,.*\$@\1@g")
                        if [[ $(echo -e "${LINE_COL_STATE}" | grep -e "a\|e\|i\|o\|u") ]];then
                            STATE_UPPER=$(echo -e "${LINE_COL_STATE}" | tr "[:lower:]" "[:upper:]" | sed -e "s@á@Á@g" -e "s@é@É@g" -e "s@í@Í@g" -e "s@ó@Ó@g" -e "s@ú@Ú@g")
                            sed -i "${LINE_CSV} s@^\(.*,\)\(.*\)\(,.*,.*,.*,.*,.*,.*\)\$@\1${STATE_UPPER}\3@g" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}"
                        fi
                        if [[ $(echo -e "${LINE_COL_DATE_SYMP}" | grep -e "[0-9][0-9][0-9][0-9][0-9]") ]];then
                            DATE_UNIX_FORMAT=$(date -d @$(( $(( ${LINE_COL_DATE_SYMP} - 25568 )) * 86400 )) +"%d/%m/%Y")
                            sed -i "${LINE_CSV} s@^\(.*,.*,.*,.*,\)\(.*\)\(,.*,.*,.*\)\$@\1${DATE_UNIX_FORMAT}\3@g" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}"
                        fi
                        LINE_TO_HASH=$(sed -n "${LINE_CSV} p" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}" | sed -e "s@^.*,\(.*,.*,.*,.*\),.*,\(.*,.*\)@\1\2@" | sed -e "s@ \|\/\|,\|*@@g")
			LINE_CSV_HASH=$(echo -e "${LINE_TO_HASH}" | md5sum | sed -e "s@.*\([0-9a-z]\{10\}\)  -.*\$@c-\1@g")
                        sed -i "${LINE_CSV} s@^\(.*,.*\),\(.*,.*,.*,.*,.*,.*\)\$@${FILE_CSV_DATE},\1,,\2,${LINE_TO_HASH},${LINE_CSV_HASH}@g" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}" 
		    else
                        LINE=$(sed -n "${LINE_CSV} p" "${DOC_PATH}${FILE_CSV}")
                        LINE_COL_STATE=$(echo -e "${LINE}" | sed -e "s@^.*,\(.*\),.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                        LINE_COL_DATE_SYMP=$(echo -e "${LINE}" | sed -e "s@^.*,.*,.*,.*,.*,\(.*\),.*,.*,.*\$@\1@g")
                        if [[ $(echo -e "${LINE_COL_STATE}" | grep -e "a\|e\|i\|o\|u") ]];then
                            STATE_UPPER=$(echo -e "${LINE_COL_STATE}" | tr "[:lower:]" "[:upper:]" | sed -e "s@á@Á@g" -e "s@é@É@g" -e "s@í@Í@g" -e "s@ó@Ó@g" -e "s@ú@Ú@g")
                            sed -i "${LINE_CSV} s@^\(.*,\)\(.*\)\(,.*,.*,.*,.*,.*,.*,.*\)\$@\1${STATE_UPPER}\3@g" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}"
                        fi
                        if [[ $(echo -e "${LINE_COL_DATE_SYMP}" | grep -e "[0-9][0-9][0-9][0-9][0-9]") ]];then
                            DATE_UNIX_FORMAT=$(date -d @$(( $(( ${LINE_COL_DATE_SYMP} - 25568 )) * 86400 )) +"%d/%m/%Y")
                            sed -i "${LINE_CSV} s@^\(.*,.*,.*,.*,.*,\)\(.*\)\(,.*,.*,.*\)\$@\1${DATE_UNIX_FORMAT}\3@g" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}"
                        fi

                        LINE_TO_HASH=$(sed -n "${LINE_CSV} p" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}" | sed -e "s@^.*,\(.*\),.*,\(.*,.*,.*\),.*,\(.*,.*\)@\1\2\3@" | sed -e "s@ \|\/\|,\|*@@g")
                        LINE_CSV_HASH=$(echo -e "${LINE_TO_HASH}" | md5sum | sed -e "s@.*\([0-9a-z]\{10\}\)  -.*\$@c-\1@g")
                        sed -i "${LINE_CSV} s@^\(.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@${FILE_CSV_DATE},\1,${LINE_TO_HASH},${LINE_CSV_HASH}@g" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}"                 
		    fi
		done

                if [[ "${COMMA_COUNT}" = "7" ]];then
                    sed -i "1 s@^\(.*,.*\),\(.*,.*,.*,.*,.*,.*\)\$@Fecha Archivo Inicial,\1,Localidad,\2,Cadena,HASH (10 ultimos)@g" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}"
                else
                    sed -i "1 s@^\(.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@Fecha Archivo Inicial,\1,Cadena,HASH (10 ultimos)@g" "${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}"
	        fi
                sed -i "1 s@^@\xef\xbb\xbf@g" ${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}
                echo -e "Se crea archivo ${MERGE_PATH}${TYPE_FILE}/${FILE_CSV}"
            fi
        done
    done
}

function copyCsv(){
    checkDirExist "csv/"
    FILES_CSV=($(find ${DOC_PATH} -name "*.csv" | sort))
    for FILE_CSV in ${FILES_CSV[*]};do
        FILE_NEW_NAME=$(echo -e "${FILE_CSV}" | sed -e "s@originales\/\(.*\)_\(.*\)_.*_.*.csv@\1_\2@g")
        FILES_NEW_CSV=($(ls "csv/"))
        FILES_ARE_SAME=1
        FLAG=1
        for FILE_NEW_CSV in ${FILES_NEW_CSV[*]};do
            FILES_ARE_SAME=$(cmp -s "${FILE_CSV}" "csv/${FILE_NEW_CSV}"; echo $?)
            if [[ ${FILES_ARE_SAME} -eq 0 ]];then
                FLAG=0
            fi
        done
        if [[ ${FLAG} -eq 1 ]];then
            cp -v --backup=numbered ${FILE_CSV} "csv/${FILE_NEW_NAME}.csv"
        fi
     done
}

function mergeCsv(){
    MERGE_FILE_NAME="supermerge.csv"
    checkUrlFile "${MERGE_PATH}" "${MERGE_FILE_NAME}"
    FILES_CSV=($(find ${MERGE_PATH} -name "*.csv" | grep -v "${MERGE_FILE_NAME}" | sed -e "s@merge/.*os/\(.*\)@\1@g" | sort | sed -e "s@\(.*\)_\(.*\)_\(.*_.*.csv\)@merge\/\2\/\1_\2_\3@g"))
    HEADER="Fecha Archivo Inicial,# Caso,Estado,Localidad,Sexo,Edad,Fecha de Inicio de sintomas,Identificacion de COVID-19 por RT-PCR en tiempo real,Procedencia,Fecha del llegada a Mexico,Cadena,HASH (10 ultimos)"
    MERGE_HEADER=$(sed -n "1 p" ${MERGE_PATH}${MERGE_FILE_NAME} | sed -e "s@^\xef\xbb\xbf@@g")
    if [[ "${HEADER}" != "${MERGE_HEADER}" ]];then
        sed -i "1i ${HEADER}" "${MERGE_PATH}${MERGE_FILE_NAME}"
        sed -i "1 s@^@\xef\xbb\xbf@g" "${MERGE_PATH}${MERGE_FILE_NAME}"
        sed -i "/^$/d" "${MERGE_PATH}${MERGE_FILE_NAME}"
    fi
    for FILE_CSV in ${FILES_CSV[*]};do
        HEADER_CSV=$(sed -n "1 p" ${FILE_CSV})
        HEADER_CSV_LEN=$(echo -e "${HEADER_CSV}" | grep -o "," | wc -l)
        if [[ "${HEADER_CSV_LEN}" = "10" ]];then
            FILE_CSV_TENLAST_LINES=$(tail -n 10 ${FILE_CSV} | sed -e "s@\(.*,.*,.*,\)\(.*,.*,.*,.*,.*,.*,.*,.*\)@\1,\2@g")
            FILE_CSV_EXIST_IN_MERGE=$(grep -e "${FILE_CSV_TENLAST_LINES}" ${MERGE_PATH}${MERGE_FILE_NAME} 1>/dev/null; echo $?)
            if [[ "${FILE_CSV_EXIST_IN_MERGE}" != "0" ]];then
                sed -n "2,$ p" "${FILE_CSV}" | sed -e "s@\(.*,.*,.*,\)\(.*,.*,.*,.*,.*,.*,.*,.*\)@\1,\2@g" >> "${MERGE_PATH}${MERGE_FILE_NAME}"
                echo -e "Se agrega ${FILE_CSV} a merge/supermerge.csv"
            fi
        elif [[ "${HEADER_CSV_LEN}" = "11" ]];then
            FILE_CSV_TENLAST_LINES=$(tail -n 10 ${FILE_CSV})
            FILE_CSV_EXIST_IN_MERGE=$(grep -e "${FILE_CSV_TENLAST_LINES}" ${MERGE_PATH}${MERGE_FILE_NAME} 1>/dev/null; echo $?)
            if [[ "${FILE_CSV_EXIST_IN_MERGE}" != "0" ]];then
                sed -n "2,$ p" "${FILE_CSV}" >> "${MERGE_PATH}${MERGE_FILE_NAME}"
                echo -e "Se agrega ${FILE_CSV} a merge/supermerge.csv"
            fi
        fi
    done
}

function csvToStandar(){
    FILE=$1
    FILE_LEN=$(wc -l ${FILE} | sed -e "s@^\(.*\) .*@\1@g")

    for FILE_LINE in $(seq 2 1 ${FILE_LEN});do
        LINE=$(sed -n "${FILE_LINE} p" "${FILE}")
        LINE_COL_STATE=$(echo -e "${LINE}" | sed -e "s@^.*,.*,\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
        LINE_COL_DATE_SYMP=$(echo -e "${LINE}" | sed -e "s@^.*,.*,.*,.*,.*,.*,\(.*\),.*,.*,.*,.*,.*\$@\1@g")
        STATE_UPPER="${LINE_COL_STATE}"
        DATE_UNIX_FORMAT="${LINE_COL_DATE_SYMP}"
        if [[ $(echo -e "${LINE_COL_STATE}" | grep -e "a\|e\|i\|o\|u") ]];then
            STATE_UPPER=$(echo -e "${LINE_COL_STATE}" | tr "[:lower:]" "[:upper:]" | sed -e "s@á@Á@g" -e "s@é@É@g" -e "s@í@Í@g" -e "s@ó@Ó@g" -e "s@ú@Ú@g")
            sed -i "${FILE_LINE} s@^\(.*,.*,\)\(.*\)\(,.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@\1${STATE_UPPER}\3@g" ${FILE}
        fi
        if [[ $(echo -e "${LINE_COL_DATE_SYMP}" | grep -e "[0-9][0-9][0-9][0-9][0-9]") ]];then
            DATE_UNIX_FORMAT=$(date -d @$(( $(( ${LINE_COL_DATE_SYMP} - 25568 )) * 86400 )) +"%d/%m/%Y")
            sed -i "${FILE_LINE} s@^\(.*,.*,.*,.*,.*,.*,\)\(.*\)\(,.*,.*,.*,.*,.*\)\$@\1${DATE_UNIX_FORMAT}\3@g" ${FILE}
        fi
    done
    echo -e "Se termina estandarizacion de archivo ${FILE}"
}

function main (){
#clear
while true;do
#date +"%Y/%m/%d %H:%M:%S.%4N"
    DAT_QURY="$(date +"%Y%m%d_%H%M%S")"
    echo -e "Inicio de consulta: ${DAT_QURY}"
    validateUrlCTD
    dwnloadFilesFromCTD
    convPdftoCsv
    makeCsvExt
    copyCsv
     mergeCsv
    echo -e "Fin de consulta: $(date +"%Y%m%d_%H%M%S")"
    invCountNewQury
done
}

main $@
