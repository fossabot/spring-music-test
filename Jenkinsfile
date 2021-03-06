#!/usr/bin/env groovy

node {
  //Delete current directory
  deleteDir()

  // Using BuildUser Plugin
  wrap([$class: 'BuildUser']) {

    // Checkout our source code from Github
    checkout scm

  // ------------------------------- Define Variables ------------------------------------------------
    SPRING_APP = "spring-music"
    APPLICATION_NAME = "${BUILD_USER_ID}-${SPRING_APP}"
    PCF_ENV = "preproduction"
    PCF_ORG = "security_lab"
    PCF_SPACE = "development"
    PCF_ENDPOINT = "https://test-deployadactyl.cfapps.io/v3/apps/"
    ARTIFACT_URL = "http://18.216.57.173:8081/artifactory/sample-test/"
    SONARQUBE_ENDPOINT = "http://18.218.227.237:9000"
    DEPENDENCYTRACK_ENDPOINT = "http://3.135.182.149:8080/"
    STATUS_ENDPOINT = "13.59.34.104:8082"
    SLEEP_SECONDS = 5
    GIT_REPO_URL = scm.userRemoteConfigs[0].url
    WORKSPACE = pwd()
    LICATION_BACKEND = "13.59.34.104:8080"
    LICATION_FRONTEND = "http://13.59.34.104/dashboard"
    LICATION_ARTIFACT_URL = "http://18.216.57.173:8081/artifactory/webapp/#/artifacts/browse/tree/General/sample-test/"
    CHECKSUM = "NOT_SET"



  // ------------------------------- Use Jenkins Credential Store ------------------------------------------------

    withCredentials([
      [
      $class          : 'StringBinding',
      credentialsId   : 'sonarqube',
      variable        : 'SONARQUBE_TOKEN'
      ],
      [
      $class          : 'StringBinding',
      credentialsId   : 'github',
      variable        : 'GIT_TOKEN'
      ],
      [
      $class          : 'UsernamePasswordMultiBinding',
      credentialsId   : 'abdel_art_user',
      passwordVariable: 'ART_PASSWORD',
      usernameVariable: 'ART_USERNAME'
      ]]){

  // ------------------------------- Spin Up Docker Container ------------------------------------------------

    docker.image('richbg/java-build-tools-dockerfile').inside(){
      withEnv(['HOME=.']) {
        env.WORKSPACE = WORKSPACE
        env.APPLICATION_NAME = APPLICATION_NAME
        env.PCF_ENDPOINT = PCF_ENDPOINT
        env.STATUS_ENDPOINT = STATUS_ENDPOINT
        env.PCF_ENV = PCF_ENV
        env.PCF_SPACE = PCF_SPACE
        env.PCF_ORG = PCF_ORG
        env.SPRING_APP = SPRING_APP
        env.SONARQUBE_ENDPOINT = SONARQUBE_ENDPOINT
        env.DEPENDENCYTRACK_ENDPOINT = DEPENDENCYTRACK_ENDPOINT
        env.ARTIFACT_URL = ARTIFACT_URL
        env.ART_USERNAME = ART_USERNAME
        env.ART_PASSWORD = ART_PASSWORD
        env.GIT_REPO_URL = GIT_REPO_URL
        env.GIT_TOKEN = GIT_TOKEN
        env.SONARQUBE_TOKEN = SONARQUBE_TOKEN
        env.LICATION_BACKEND = LICATION_BACKEND
        env.LICATION_FRONTEND = LICATION_FRONTEND
        env.LICATION_ARTIFACT_URL = LICATION_ARTIFACT_URL
        env.SLEEP_SECONDS = SLEEP_SECONDS
    
  // ------------------------------- Run Jenkins Stages (Steps) ------------------------------------------------
      // Download our Spring Application Artifacts from Artifactory
      stage("Pull Spring Music Artifacts") {
        sh '''
        DIRECTORY="pcf_artifacts"
          if [ -d "$DIRECTORY" ]; then
            echo "Deleting: $DIRECTORY directory"
            rm -rf pcf_artifacts
          fi
          mkdir pcf_artifacts && mv manifest.yml pcf_artifacts
          curl -s -u${ART_USERNAME}:${ART_PASSWORD} -O "${ARTIFACT_URL}${SPRING_APP}.zip"
          unzip ${SPRING_APP}.zip
          '''
      }
      // Build & Test our spring application using Gradle Build Automation
      stage("Build Project & Create BOM") {
        sh '''
          cd ~/$PROJECT_NAME/${SPRING_APP}
          ./gradlew clean assemble cyclonedxBom
          '''
      }
      // Run SonarQube Code Quality and Security Scan
      stage('SonarQube analysis') {
        withSonarQubeEnv() {
          sh '''
            cd ${SPRING_APP}
            ./gradlew sonarqube \
            -Dsonar.projectName=${APPLICATION_NAME} \
            -Dsonar.projectKey=${APPLICATION_NAME} \
            -Dsonar.host.url=${SONARQUBE_ENDPOINT} \
            -Dsonar.login=${SONARQUBE_TOKEN}
            '''
        }
      }
      
      // Upload our application jar file to Artifactory
      stage("Upload to Artifactory") {
        script{
          CHECKSUM = sh(script: '''
          cd ~/$PROJECT_NAME/${SPRING_APP}/build/libs
          file=`ls *.jar`
          curl -s -u${ART_USERNAME}:${ART_PASSWORD} -T ${file} ${ARTIFACT_URL}${APPLICATION_NAME}_${BUILD_NUMBER}.jar | jq -r '.checksums.sha1'
          ''', returnStdout: true).trim()
        }
          env.CHECKSUM=CHECKSUM

        sh '''
        cd ${WORKSPACE}/$PROJECT_NAME/${SPRING_APP}/build/libs
        file=`ls *.jar`
        manifest_app_name="spring-music-1.0.jar"
          cp ${file} ${WORKSPACE}/$PROJECT_NAME/pcf_artifacts && cd ../reports
          curl -s -u${ART_USERNAME}:${ART_PASSWORD} -T bom.xml "${ARTIFACT_URL}bom.xml"
          cd ${WORKSPACE}/$PROJECT_NAME && zip -r pcf_artifacts.zip pcf_artifacts
        '''
      }
      // Call lication security scan service to aggregate results
      stage("(app)Lication Security Service") {
        sh '''
        cd ${WORKSPACE}/$PROJECT_NAME
        chmod 700 lication_endpoint.sh
        ./lication_endpoint.sh
        '''
        script{
          RESULTS = sh(script: '''
          curl -s ${STATUS_ENDPOINT}"/sha/"${CHECKSUM} | jq -r '.scanStatus'
          ''', returnStdout: true).trim()
          env.RESULTS=RESULTS
        }
        sh '''
           cd ${WORKSPACE}/$PROJECT_NAME
           chmod 700 lication.sh
           ./lication.sh
          '''
      }
      stage("View Results"){
        sh '''
        set -x
        echo -e "SonarQube EndPoint: ${SONARQUBE_ENDPOINT}\n User/Password = system/csnpworkshop01"
        echo -e "DependencyTrack Endpoint: ${DEPENDENCYTRACK_ENDPOINT}\n User/Password = system/csnpworkshop01"
        echo "Your Application Direct URL:" https://${APPLICATION_NAME}.cfapps.io
        echo "Security Service URL: ${LICATION_FRONTEND}"
        '''
      }
     }
    }
   }
  }
}