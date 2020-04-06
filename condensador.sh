#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"
TIME=$(date +"%H%M%S")
DAY=$(echo -e "$1" | sed -e "s@^\([0-9][0-9]\)/\([0-9][0-9]\)/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
DATEP=$(echo -e "${DAY}_${TIME}")

function main(){
    DATE_FILE_COMPARE="$1"
    FILE_CONDEN_PATH="condensados/"
    FILE_CONDEN_NAME="$(echo -e "condensado_${DATEP}.csv")"
    FILE_SUPERMERGE_ORIG="merge/supermerge.csv"
    FILE_SUPERMERGE="merge/sm.tmp"
    sed -n "1 p" ${FILE_SUPERMERGE_ORIG} > "${FILE_SUPERMERGE}"
    grep -v "^${DATE_FILE_COMPARE},.*onfirmado,.*" "${FILE_SUPERMERGE_ORIG}" >> "${FILE_SUPERMERGE}"
    FILE_COMPARE="merge/a.tmp"
    sed -n "1 p" ${FILE_SUPERMERGE_ORIG} > "${FILE_COMPARE}"
    grep -e "^${DATE_FILE_COMPARE},.*onfirmado,.*" "${FILE_SUPERMERGE_ORIG}" >> "${FILE_COMPARE}"
    FILE_COMPARE_LINES=($(sed -n "2,$ p" "${FILE_COMPARE}" | tr " " "#"))
    FILE_COMPARE_COUNTA=$(sed -n "2,$ p" "${FILE_COMPARE}" | wc -l)
    FILE_COMPARE_HEADER="$(sed -n "1 p" "${FILE_COMPARE}" | sed -e "s@^\(.*\),\(.*,.*,.*,.*,.*,.*,.*,.*,.*\),\(.*\),\(.*\)\$@\2,\3@g")"
    CSV_FILE_HISTORY="$(echo -e "${FILE_COMPARE_HEADER},Ambiguo,Ingreso Sospechosos,Ultimo Sospechosos,Diferencia Sospechosos,Ingreso Positivos,Ultimo Positivos,Diferencia Positivos,Historial Sospechosos,Historial Positivos")"
    echo -e "${CSV_FILE_HISTORY}" > ${FILE_CONDEN_PATH}${FILE_CONDEN_NAME}
    sed -i "1 s@^@\xef\xbb\xbf@g" ${FILE_CONDEN_PATH}${FILE_CONDEN_NAME}
    echo -e "Se crea ${FILE_CONDEN_PATH}${FILE_CONDEN_NAME}"

    for FILE_COMPARE_COUNT in $(seq 2 1 $(( ${#FILE_COMPARE_LINES[*]} +1 )));do
        FILE_COMPARE_LINE=$(sed -n "${FILE_COMPARE_COUNT} p" "${FILE_COMPARE}" | tr "#" " ")
        COMPARE_ID=$(echo -e "${FILE_COMPARE_LINE}" | sed -e "s@^.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\(.*\),.*\$@\1@g")
        LINES_COMPARE_EXIST=$(grep -e ",${COMPARE_ID}," "${FILE_SUPERMERGE}" 1>/dev/null ; echo $?)
        COMPARE_ID_AMBIGUOUS_EXISTS=$(grep -e ",${COMPARE_ID}," "${FILE_SUPERMERGE_ORIG}" | grep -e "^${DATE_FILE_COMPARE},.*,.*,.*,.*,.*,.*,.*onfirmado.*" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g" | uniq -c | grep -v "      1" 1>/dev/null ; echo $?)

        if [[ "${COMPARE_ID_AMBIGUOUS_EXISTS}" = "1" ]];then
            AMBIGUOUS="NO"

        elif [[ "${COMPARE_ID_AMBIGUOUS_EXISTS}" = "0" ]];then
            AMBIGUOUS="SI"

        fi

        if [[ "${LINES_COMPARE_EXIST}" = "0" ]];then
            LINES_COMPARE=$(grep -e ",${COMPARE_ID}," "${FILE_SUPERMERGE}")
            LINES_COMPARE_COUNT=$(grep -e ",${COMPARE_ID}," "${FILE_SUPERMERGE}" | wc -l )
            SOS_LINE_EXIST=$(grep -e ",${COMPARE_ID}," "${FILE_SUPERMERGE}" | grep -e "ospechoso" | head -n 1 1>/dev/null ; echo $?)
            POS_LINE_EXIST=$(grep -e ",${COMPARE_ID}," "${FILE_SUPERMERGE}" | grep -e "onfirmado" | head -n 1 1>/dev/null ; echo $?)

            if [[ "${SOS_LINE_EXIST}" = "0" ]];then
                SOS_LINES=$(grep -e ",${COMPARE_ID}," "${FILE_SUPERMERGE}" | grep -e "ospechoso")
                SOS_LINE_COUNT=$(echo -e "${SOS_LINES}" | wc -l)

                if [[ ${SOS_LINE_COUNT} -eq 1 ]];then
                    SOS_LINE_FIRST=$(echo -e "${SOS_LINES}" | sed -n "1 p")
                    SOS_LINE_FIRST_DATE=$(echo -e "${SOS_LINE_FIRST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    SOS_LINE_FIRST_DATE_STD=$(echo -e "${SOS_LINE_FIRST_DATE}" | sed -e "s@^\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
                    SOS_LINE_LAST="${SOS_LINE_FIRST}"
                    SOS_LINE_LAST_DATE="${SOS_LINE_FIRST_DATE}"
                    SOS_LINE_LAST_DATE_STD=$(echo -e "${SOS_LINE_LAST_DATE}" | sed -e "s@^\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
                    SOS_LINE_DATE_DIFF=$(($(($(( $(date +%s -d "${SOS_LINE_LAST_DATE_STD}") - $(date +%s -d "${SOS_LINE_FIRST_DATE_STD}") )) / 86400 )) + 1 ))
                    SOS_LINE_HISTORY=$(echo -e "${SOS_LINES}" | sed -e "s@^\(.*\),\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@(\1-\2)@g" | tr "\n" " " | sed -e "s@ \$@@g")

                elif [[ ${SOS_LINE_COUNT} -ge 1 ]];then
                    SOS_LINE_FIRST=$(echo -e "${SOS_LINES}" | sed -n "1 p")
                    SOS_LINE_FIRST_DATE=$(echo -e "${SOS_LINE_FIRST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    SOS_LINE_FIRST_DATE_STD=$(echo -e "${SOS_LINE_FIRST_DATE}" | sed -e "s@^\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
                    SOS_LINE_LAST=$(echo -e "${SOS_LINES}" | sed -n "$ p")
                    SOS_LINE_LAST_DATE=$(echo -e "${SOS_LINE_LAST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    SOS_LINE_LAST_DATE_STD=$(echo -e "${SOS_LINE_LAST_DATE}" | sed -e "s@^\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
                    SOS_LINE_DATE_DIFF=$(($(($(( $(date +%s -d "${SOS_LINE_LAST_DATE_STD}") - $(date +%s -d "${SOS_LINE_FIRST_DATE_STD}") )) / 86400 )) + 1 ))
                    SOS_LINE_HISTORY=$(echo -e "${SOS_LINES}" | sed -e "s@^\(.*\),\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@(\1-\2)@g" | tr "\n" " " | sed -e "s@ \$@@g")

                fi

            elif [[ "${SOS_LINE_EXIST}" = "1" ]];then
                SOS_LINE_COUNT="0"
                SOS_LINE_FIRST="NA"
                SOS_LINE_FIRST_DATE="NA"
                SOS_LINE_FIRST_DATE_STD="NA"
                SOS_LINE_LAST="NA"
                SOS_LINE_LAST_DATE="NA"
                SOS_LINE_LAST_DATE_STD="NA"
                SOS_LINE_DATE_DIFF=0
                SOS_LINE_HISTORY="NA"

            fi

            if [[ "${POS_LINE_EXIST}" = "0" ]];then
                POS_LINES=$(grep -e ",${COMPARE_ID}," "${FILE_SUPERMERGE}" | grep -e "onfirmado")
                POS_LINE_COUNT=$(echo -e "${POS_LINES}" | wc -l)

                if [[ ${POS_LINE_COUNT} -eq 1 ]];then
                    POS_LINE_FIRST=$(echo -e "${POS_LINES}" | sed -n "1 p")
                    POS_LINE_FIRST_DATE=$(echo -e "${POS_LINE_FIRST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    POS_LINE_FIRST_DATE_STD=$(echo -e "${POS_LINE_FIRST_DATE}" | sed -e "s@^\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
                    POS_LINE_LAST=$(echo -e "${FILE_COMPARE_LINE}")
                    POS_LINE_LAST_DATE=$(echo -e "${POS_LINE_LAST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    POS_LINE_LAST_DATE_STD=$(echo -e "${POS_LINE_LAST_DATE}" | sed -e "s@^\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
                    POS_LINE_DATE_DIFF=$(($(($(( $(date +%s -d "${POS_LINE_LAST_DATE_STD}") - $(date +%s -d "${POS_LINE_FIRST_DATE_STD}") )) / 86400 )) + 1 ))
                    POS_LINE_HISTORY=$(echo -e "${POS_LINES}" | sed -e "s@^\(.*\),\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@(\1-\2)@g" | tr "\n" " " | sed -e "s@ \$@@g")

                elif [[ ${POS_LINE_COUNT} -ge 1 ]];then
                    POS_LINE_FIRST=$(echo -e "${POS_LINES}" | sed -n "1 p")
                    POS_LINE_FIRST_DATE=$(echo -e "${POS_LINE_FIRST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    POS_LINE_FIRST_DATE_STD=$(echo -e "${POS_LINE_FIRST_DATE}" | sed -e "s@^\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
                    POS_LINE_LAST=$(echo -e "${FILE_COMPARE_LINE}")
                    POS_LINE_LAST_DATE=$(echo -e "${POS_LINE_LAST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    POS_LINE_LAST_DATE_STD=$(echo -e "${POS_LINE_LAST_DATE}" | sed -e "s@^\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9][0-9][0-9]\)\$@\3\2\1@g")
                    POS_LINE_DATE_DIFF=$(($(($(( $(date +%s -d "${POS_LINE_LAST_DATE_STD}") - $(date +%s -d "${POS_LINE_FIRST_DATE_STD}") )) / 86400 )) + 1 ))
                    POS_LINE_HISTORY=$(echo -e "${POS_LINES}" | sed -e "s@^\(.*\),\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@(\1-\2)@g" | tr "\n" " " | sed -e "s@ \$@@g")

                fi

            elif [[ "${POS_LINE_EXIST}" = "1" ]];then
                POS_LINE_COUNT="0"
                POS_LINE_FIRST=$(echo -e "${FILE_COMPARE_LINE}")
                POS_LINE_FIRST_DATE=$(echo -e "${POS_LINE_FIRST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                POS_LINE_FIRST_DATE_STD="NA"
                POS_LINE_LAST=$(echo -e "${FILE_COMPARE_LINE}")
                POS_LINE_LAST_DATE=$(echo -e "${POS_LINE_LAST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                POS_LINE_LAST_DATE_STD="NA"
                POS_LINE_DATE_DIFF=1
                POS_LINE_HISTORY="NA"

            fi

        elif [[ "${LINES_COMPARE_EXIST}" = "1" ]];then
            LINES_COMPARE=""
            LINES_COMPARE_COUNT=0
            SOS_LINE_COUNT="0"
            SOS_LINE_FIRST="NA"
            SOS_LINE_FIRST_DATE="NA"
            SOS_LINE_FIRST_DATE_STD="NA"
            SOS_LINE_LAST="NA"
            SOS_LINE_LAST_DATE="NA"
            SOS_LINE_LAST_DATE_STD="NA"
            SOS_LINE_DATE_DIFF=0
            SOS_LINE_HISTORY="NA"
            POS_LINE_COUNT="0"
            POS_LINE_FIRST=$(echo -e "${FILE_COMPARE_LINE}")
            POS_LINE_FIRST_DATE=$(echo -e "${POS_LINE_FIRST}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
            POS_LINE_FIRST_DATE_STD="NA"
            POS_LINE_LAST=$(echo -e "${FILE_COMPARE_LINE}")
            POS_LINE_LAST_DATE=$(echo -e "${POS_LINE_FIRST_DATE}")
            POS_LINE_LAST_DATE_STD="NA"
            POS_LINE_DATE_DIFF=1
#            POS_LINE_HISTORY=$(echo -e "$FILE_COMPARE_LINE{}" | sed -e "s@^\(.*\),\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@(\1-\2)@g" | tr "\n" " " | sed -e "s@ \$@@g")
            POS_LINE_HISTORY="NA"

        fi

        FILE_COMPARE_LINE_SHORT="$(echo -e "${FILE_COMPARE_LINE}" | sed -e "s@^\(.*\),\(.*,.*,.*,.*,.*,.*,.*,.*,.*\),\(.*\),\(.*\)\$@\2,\3@g")"
        echo -e "${FILE_COMPARE_LINE_SHORT},${AMBIGUOUS},${SOS_LINE_FIRST_DATE},${SOS_LINE_LAST_DATE},${SOS_LINE_DATE_DIFF},${POS_LINE_FIRST_DATE},${POS_LINE_LAST_DATE},${POS_LINE_DATE_DIFF},${SOS_LINE_HISTORY},${POS_LINE_HISTORY}" >> ${FILE_CONDEN_PATH}${FILE_CONDEN_NAME}

    MOD_A=$((( ${FILE_COMPARE_COUNT} % 300 )))

    if [[ "${MOD_A}" == "0" ]];then
	    echo -e "${FILE_COMPARE_COUNT} registros revisados"

    fi


    done
    echo -e "$(( ${FILE_COMPARE_COUNT} - 1 )) registros revisados"
    rm -rf "${FILE_SUPERMERGE}" "${FILE_COMPARE}"


}

function desambiguous(){
    FILE_SM="merge/supermerge.csv"
    COND_PATH="condensados/"
    FILE_CHAN="cambios.csv"
    DEL_LINES=0
    OLD_LINES=0
    NEW_LINES=0
    NEW_LINESA=0
    TOD="$1"
    YES="$(date -d "${TOD} -1 days" +"%d/%m/%Y")"
    TOD_A=$(echo -e "${TOD}" | sed -e "s@^\(.*\)/\(.*\)/\(.*\)\$@\3\2\1@g")
#    COND_NAME="$(ls -l "${COND_PATH}" | grep -e "condensado_${DATEP}.csv$" | tail -n 1 | sed -e "s@.*condensado_\(.*\)\$@condensado_\1@g")"
    COND_NAME="$(echo -e "condensado_${DATEP}.csv")"
    COND_NAME_B="$(echo -e "${COND_NAME}" | sed -e "s@^\(.*\)\$@\1.bkp@g")"
    RETI_NAME=$(echo -e "${COND_NAME}" | sed -e "s@^condensado\(.*\)\$@retirados\1@g")
    FILE_SM_COMP_LINES=($(cat ${FILE_SM} | grep -e "^.*,.*,.*,.*,.*,.*,.*,.*onfirmado,.*,.*,.*,.*" | grep -e "^${YES},.*" -e "^${TOD},.*" | sed -e "s@\(.*,.*,.*,.*,.*,.*,.*,.*,.*,\)\(.*\)\(,.*\)@\2@g" | sort | uniq))
    FILE_SM_COMP_LINES_LEN="$(echo -e "${FILE_SM_COMP_LINES[*]}" | tr " " "\n" | wc -l)"
    FILE_SM_COMP_LINES_COU=1
    DIF_LINES=0
    cp "${COND_PATH}${COND_NAME}" "${COND_PATH}${COND_NAME_B}"
    sed -n "1 p" "${FILE_SM}" > "${COND_PATH}${RETI_NAME}"
    sed -i "1 s@^@\xef\xbb\xbf@g" "${COND_PATH}${RETI_NAME}"

    for FILE_SM_COMP_LINE in ${FILE_SM_COMP_LINES[*]};do
	YES_LINES_EXS=$(cat ${FILE_SM} | grep -e "^${YES},.*,.*,.*,.*,.*,.*,.*onfirmado,.*,.*,${FILE_SM_COMP_LINE},.*" 1>/dev/null ; echo $?)
	TOD_LINES_EXS=$(cat ${FILE_SM} | grep -e "^${TOD},.*,.*,.*,.*,.*,.*,.*onfirmado,.*,.*,${FILE_SM_COMP_LINE},.*" 1>/dev/null ; echo $?)

	if [[ "${YES_LINES_EXS}" = "0" ]] && [[ "${TOD_LINES_EXS}" = "1" ]];then
            YES_LINES="$(cat ${FILE_SM} | grep -e "^${YES},.*,.*,.*,.*,.*,.*,.*onfirmado,.*,.*,${FILE_SM_COMP_LINE},.*")"
	    YES_LINES_LEN=$(echo -e "${YES_LINES}" | wc -l)
	    TOD_LINES=""
	    TOD_LINES_LEN=0
            DIF_LINES=$(( ${TOD_LINES_LEN} - ${YES_LINES_LEN} ))

            if [[ "${DIF_LINES}" -lt "0" ]];then

                for REP in $(seq 1 1 $(( ${DIF_LINES} * -1 )));do
                    DEL_LINES=$(( ${DEL_LINES} + 1 ))
                    LINE_SUS=$(grep -e "^${YES},.*onfirmado,.*,${FILE_SM_COMP_LINE}," "${FILE_SM}")
                    echo -e "${LINE_SUS}" >> "${COND_PATH}${RETI_NAME}"

                done
	    fi
	    
        elif [[ "${YES_LINES_EXS}" = "0" ]] && [[ "${TOD_LINES_EXS}" = "0" ]];then
            YES_LINES="$(cat ${FILE_SM} | grep -e "^${YES},.*,.*,.*,.*,.*,.*,.*onfirmado,.*,.*,${FILE_SM_COMP_LINE},.*")"
            YES_LINES_LEN=$(echo -e "${YES_LINES}" | wc -l)
            TOD_LINES="$(cat ${FILE_SM} | grep -e "^${TOD},.*,.*,.*,.*,.*,.*,.*onfirmado,.*,.*,${FILE_SM_COMP_LINE},.*")"
            TOD_LINES_LEN=$(echo -e "${TOD_LINES}" | wc -l)
            DIF_LINES=$(( ${TOD_LINES_LEN} - ${YES_LINES_LEN} ))
            TOD_LINES_S="$(echo -e "${TOD_LINES}" | sed -e "s@^.*,\(.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\).*\$@\1@g")"

            # No hay casos para comprobar existen Y y T pero la diferencia es negativa, se agregan OLD y DEL	    
            if [[ "${DIF_LINES}" -lt "0" ]];then

                for REP in $(seq 1 1 ${TOD_LINES_LEN});do
                    OLD_LINES=$(( ${OLD_LINES} + 1 ))
#                    echo -e "${REP} YE_TE lt0 old ${OLD_LINES}"
                    LINE_SUS=$(grep -e "^${TOD},.*onfirmado,.*,${FILE_SM_COMP_LINE}," "${COND_PATH}${COND_NAME}" | sed -n "${REP} p")
                    LINE_SUS_N=$(echo -e "${LINE_SUS}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    LINE_SUS_UP=$(sed -n "$(( ${LINE_SUS_N} + 1 )) p" "${COND_PATH}${COND_NAME}" | sed -e "s@^\(.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\)\(.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@\1SINCAMBIOSA,\2@g")
#                    echo -e "${LINE_SUS_UP}"
                    sed -i "$(( ${LINE_SUS_N} + 1 )) s@^.*\$@${LINE_SUS_UP}@g" "${COND_PATH}${COND_NAME_B}"

                done

		for REP in $(seq 1 1 $(( ${DIF_LINES} * -1 )));do
                    DEL_LINES=$(( ${DEL_LINES} + 1 ))
#                    echo -e "${REP} YE_TE lt0 del ${DEL_LINES}"
		    LINE_SUS=$(grep -e "^${YES},.*onfirmado,.*,${FILE_SM_COMP_LINE}," "${FILE_SM}")
                    echo -e "${LINE_SUS}" >> "${COND_PATH}${RETI_NAME}"

                done

            elif [[ "${DIF_LINES}" -eq "0" ]];then

                for REP in $(seq 1 1 ${TOD_LINES_LEN});do
                    OLD_LINES=$(( ${OLD_LINES} + 1 ))
#                    echo -e "${REP} YE_TE eq0 old ${OLD_LINES}"
		    LINE_SUS=$(grep -e "^.*onfirmado,.*,${FILE_SM_COMP_LINE}," "${COND_PATH}${COND_NAME}" | sed -n "${REP} p")
		    LINE_SUS_N=$(echo -e "${LINE_SUS}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
		    LINE_SUS_UP=$(sed -n "$(( ${LINE_SUS_N} + 1 )) p" "${COND_PATH}${COND_NAME}" | sed -e "s@^\(.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\)\(.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@\1SINCAMBIOS,\2@g")
#		    echo -e "${LINE_SUS_UP}"
                    sed -i "$(( ${LINE_SUS_N} + 1 )) s@^.*\$@${LINE_SUS_UP}@g" "${COND_PATH}${COND_NAME_B}"

                done

            elif [[ "${DIF_LINES}" -gt "0" ]];then

                for REP in $(seq 1 1 ${YES_LINES_LEN});do
                    OLD_LINES=$(( ${OLD_LINES} + 1 ))
#                    echo -e "${REP} YE_TE lt0 old ${OLD_LINES}"
                    LINE_SUS=$(grep -e ".*onfirmado,.*,${FILE_SM_COMP_LINE}," "${COND_PATH}${COND_NAME}" | sed -n "${REP} p")
                    LINE_SUS_N=$(echo -e "${LINE_SUS}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    LINE_SUS_UP=$(sed -n "$(( ${LINE_SUS_N} + 1 )) p" "${COND_PATH}${COND_NAME}" | sed -e "s@^\(.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\)\(.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@\1SINCAMBIOSB,\2@g")
#                    echo -e "${LINE_SUS_UP}"
                    sed -i "$(( ${LINE_SUS_N} + 1 )) s@^.*\$@${LINE_SUS_UP}@g" "${COND_PATH}${COND_NAME_B}"
		    
                done

                for REP in $(seq 1 1 ${DIF_LINES});do
                    NEW_LINES=$(( ${NEW_LINES} + 1 ))
#                    echo -e "${REP} YE_TE lt0 new ${NEW_LINES}"
		    LINE_SUS=$(grep -e ".*onfirmado,.*,${FILE_SM_COMP_LINE}," "${COND_PATH}${COND_NAME}" | sed -n "$(( ${REP} + ${YES_LINES_LEN} )) p")
                    LINE_SUS_N=$(echo -e "${LINE_SUS}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    LINE_SUS_UP=$(sed -n "$(( ${LINE_SUS_N} + 1 )) p" "${COND_PATH}${COND_NAME}" | sed -e "s@^\(.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\)\(.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@\1NUEVOA,\2@g")
#                   echo -e "${LINE_SUS_UP}"
                    sed -i "$(( ${LINE_SUS_N} + 1 )) s@^.*\$@${LINE_SUS_UP}@g" "${COND_PATH}${COND_NAME_B}"

                done

            fi
	    

        elif [[ "${YES_LINES_EXS}" = "1" ]] && [[ "${TOD_LINES_EXS}" = "0" ]];then
            YES_LINES=""
            YES_LINES_LEN=0
            TOD_LINES="$(cat ${FILE_SM} | grep -e "^${TOD},.*,.*,.*,.*,.*,.*,.*onfirmado,.*,.*,${FILE_SM_COMP_LINE},.*")"
            TOD_LINES_LEN=$(echo -e "${TOD_LINES}" | wc -l)
            DIF_LINES=$(( ${TOD_LINES_LEN} - ${YES_LINES_LEN} ))
            TOD_LINES_S="$(echo -e "${TOD_LINES}" | sed -e "s@^.*,\(.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\).*\$@\1@g" | tail -n ${DIF_LINES})"

            if [[ "${DIF_LINES}" -gt "0" ]];then

                for REP in $(seq 1 1 ${DIF_LINES});do
                    NEW_LINES=$(( ${NEW_LINES} + 1 ))
#                    echo -e "${REP} YN_TE gt0 new ${NEW_LINES}"
                    LINE_SUS=$(grep -e ".*onfirmado,.*,${FILE_SM_COMP_LINE}," "${COND_PATH}${COND_NAME}" | sed -n "${REP} p")
                    LINE_SUS_N=$(echo -e "${LINE_SUS}" | sed -e "s@^\(.*\),.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,.*\$@\1@g")
                    LINE_SUS_UP=$(sed -n "$(( ${LINE_SUS_N} + 1 )) p" "${COND_PATH}${COND_NAME}" | sed -e "s@^\(.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\)\(.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@\1NUEVO,\2@g")
#                   echo -e "${LINE_SUS_UP}"
                    sed -i "$(( ${LINE_SUS_N} + 1 )) s@^.*\$@${LINE_SUS_UP}@g" "${COND_PATH}${COND_NAME_B}"

                done
 
            fi
        fi

        MOD_A=$((( ${FILE_SM_COMP_LINES_COU} % 300 )))

        if [[ "${MOD_A}" = "0" ]];then
            echo -e "${FILE_SM_COMP_LINES_COU} registros revisados"

        fi

	FILE_SM_COMP_LINES_COU=$(( ${FILE_SM_COMP_LINES_COU} +  1 ))

    done

    sed -i "1 s@^\(.*,.*,.*,.*,.*,.*,.*,.*,.*,.*,\)\(.*,.*,.*,.*,.*,.*,.*,.*,.*\)\$@\1Cambios,\2@g" "${COND_PATH}${COND_NAME_B}"

    mv -f "${COND_PATH}${COND_NAME_B}" "${COND_PATH}${COND_NAME}"
    LINE_CHAN=$(echo -e "${TOD},${DEL_LINES},${OLD_LINES},${NEW_LINES},$(( ${OLD_LINES} + ${NEW_LINES} ))")
    LINE_CHAN_EX=$(grep -e "${LINE_CHAN}" "${COND_PATH}${FILE_CHAN}" 1>/dev/null;echo $?)

    if [[ "${LINE_CHAN_EX}" = "1"  ]];then
	echo -e "${LINE_CHAN}" >> "${COND_PATH}${FILE_CHAN}"

    fi
    echo -e "${FILE_SM_COMP_LINES_COU} registros revisados"
    echo -e "SALEN: ${DEL_LINES}"
    echo -e "PERMANECEN: ${OLD_LINES}"
    echo -e "INGRESAN: ${NEW_LINES}"
}
echo -e "\nSe inicia condensado"
main $@
echo -e "\nSe inicia conteo de casos"
desambiguous $1
