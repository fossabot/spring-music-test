#!/bin/bash

RESULTS=""

GIT_REPO_URL="${GIT_REPO_URL%.*}"
echo "LICATION_ARTIFACT_URL: ${LICATION_ARTIFACT_URL}${APPLICATION_NAME}_${BUILD_NUMBER}.jar"
echo "ART_USERNAME: ${ART_USERNAME}"
echo "GIT_REPO_URL: ${GIT_REPO_URL}"
echo "BUILD_NUMBER: ${BUILD_NUMBER}"
echo "LICATION_BACKEND: ${LICATION_BACKEND}"
echo "CHECKSUM: ${CHECKSUM}"
echo "STATUS_ENDPOINT: ${STATUS_ENDPOINT}"

    lication_status=`curl -XPOST -H 'Content-type: application/json' -d "{
        \"artifactUrl\": \"${LICATION_ARTIFACT_URL}${APPLICATION_NAME}_${BUILD_NUMBER}.jar\",
        \"artifactUser\": \"${ART_USERNAME}\",
        \"artifactPass\": \"${ART_PASSWORD}\",
        \"githubUrl\": \"${GIT_REPO_URL}\",
        \"jenkinsJobID\": \"${BUILD_NUMBER}\",
        \"githubCreds\": \"${GIT_TOKEN}\"
        }" "${LICATION_BACKEND}"`

    RESPONSE=`curl ${STATUS_ENDPOINT}"/sha/"${CHECKSUM}`
    echo ${RESPONSE}
    echo "Results stats above"
    RESULTS="${RESPONSE}"

while [ "$RESULTS" = "" ]
do 
    echo "Checking scan status...LOOP"
    RESPONSE=$(curl ${STATUS_ENDPOINT}"/sha/"${CHECKSUM})
    # | jq -r '.scanStatus'
    echo ${RESPONSE}
    echo "Results stats above"
    RESULTS="${RESPONSE}"


    if [ "$RESULTS" = 2 ]
    then
        echo "Scan status is still pending..."
        RESULTS=""
        sleep ${SLEEP_SECOND}
    
    elif [ "$RESULTS" = 0 ]
    then
        echo -e "Scan completed!\n"
        echo "No vulnerabilities found, deploying ${APPLICATION_NAME}..."
        cd "${WORKSPACE}/$PROJECT_NAME"
        curl -X POST \
            -H 'Content-Type: application/zip' \
            --data-binary @"pcf_artifacts.zip" \
            "${PCF_ENDPOINT}${PCF_ENV}/${PCF_ORG}/${PCF_SPACE}/${APPLICATION_NAME}"
    
    elif [ "$RESULTS" = 1 ]
    then
        echo -e "Scan Completed!\n"
        echo -e "Security Test Failed! Cannot Deploy ${APPLICATION_NAME}!"
        exit 1
    elif [[ "$RESULTS" =~ "null" ]]
    then
        echo "Return value is null!"
        exit 1
    else
        echo "Something went wrong! Please review logs"
        echo "results: ${RESULTS}"
        exit 1
    fi
done