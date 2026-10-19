// Equivalente del flujo de CI/CD del SIGR para Jenkins.
pipeline {
  agent any
  options { timeout(time: 15, unit: 'MINUTES') }
  stages {
    stage('Construcción')        { steps { sh './scripts/pipeline.sh construir' } }
    stage('Pruebas y cobertura') { steps { sh './scripts/pipeline.sh probar' } }
    stage('Seguridad')           { steps { sh './scripts/pipeline.sh seguridad' } }
    stage('Rendimiento')         { steps { sh './scripts/pipeline.sh rendimiento' } }
    stage('Empaquetado')         { steps { sh './scripts/pipeline.sh empaquetar' } }
    stage('Despliegue a staging') {
      when { branch 'main' }
      steps {
        sh './scripts/pipeline.sh desplegar'
        sh './scripts/pipeline.sh humo'
      }
    }
  }
  post {
    failure { echo 'El pipeline falló: revisar la etapa marcada en rojo.' }
  }
}
