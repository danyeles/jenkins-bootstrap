// Define ArrSeed as a Pipeline job whose script is checked out from the public infra repository.
pipelineJob('ArrSeed') {
    description('Generates the home media deployment jobs from jenkins-infra/seed.groovy.')
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/danyeles/jenkins-infra.git')
                    }
                    branch('*/main')
                }
            }
            scriptPath('seed.groovy')
            lightweight(true)
        }
    }
}