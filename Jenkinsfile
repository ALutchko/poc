pipeline {
    environment {
        TF_IN_AUTOMATION = true
        TF_INPUT = false
        S3_BUCKET_SSH = "com.dodax.infrastructure.terraform.sshkeys"
        S3_BUCKET_SSL = "com.dodax.infrastructure.terraform.ssl"
        TF_WORKSPACE = "${DEPLOY_ENV}"
        destination_role = "arn:aws:iam::313829517975:role/jenkins_executor"
        tf_vars=" " //-var cluster_name=${cluster_name}"
    }
    agent {
        dockerfile {
            label "ec2-fleet"
            filename 'terraform.Dockerfile'
            dir 'ci'
        }
    }
    parameters {
        choice(name: 'ACTION', choices: ['Plan/Apply', 'Nada', 'Destroy'], description: 'What should we do with the stack?')
        choice(name: 'DEPLOY_ENV', choices: ['test', 'prod'], description: 'Choose the environment to deploy to')
    }

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        ansiColor('xterm')
    }

    stages {
        stage('Initialization') {
            steps {
                addGithubToKnownHosts()
                terraformInit()
            }
        }

        stage('Plan') {
            when {
                expression { params.ACTION == "Plan/Apply" }
            }
            steps {
                terraformPlan(env.TF_WORKSPACE)
            }
        }

        stage ('Approval') {
            when {
                expression { params.ACTION == "Nada" }
            }
            options {
                timeout(time: 20, unit: 'MINUTES')
            }
            steps {
                input message: "Do you want to proceed with: $ACTION?"
            }
        }

        stage('Destroy') {
            when {
                expression { params.ACTION == "Destroy" }
            }
            steps {
                sh """
                terraform destroy ${tf_vars} -auto-approve
                export TF_WORKSPACE=
                terraform workspace select default
                terraform workspace delete ${TF_WORKSPACE}
                """
            }
        }

        stage ('Terraform Apply') {
            when {
                expression { params.ACTION == "Plan/Apply" }
            }
            steps {
                sh """
                ls -l
                #export TF_LOG=DEBUG
                terraform apply ./${TF_WORKSPACE}.tfplan
                #export TF_LOG=
                """
            }
        }
    }

    post {
        cleanup {
            node("ec2-fleet") {
            cleanWs() }
        }
    }
}

def prepareSSHKeys(String environment) {
    sh "mkdir /tmp/ssh_keys-$environment"
    sh "aws s3 sync s3://${S3_BUCKET_SSH}/$environment /tmp/ssh_keys-$environment/"
    sh "chmod 600 /tmp/ssh_keys-$environment/*"
}

def prepareSSLFiles(String environment) {
    sh "mkdir /tmp/ssl-$environment"
    sh "aws s3 sync s3://${S3_BUCKET_SSL}/$environment /tmp/ssl-$environment/"
}

def addGithubToKnownHosts() {
    sh """
    whoami
    mkdir -p ~/.ssh
    ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
    mkdir -p ~/.aws
    echo \"[default]\noutput = json\nregion = eu-central-1\n\" > ~/.aws/config
    """
}

def terraformInit() {
    withCredentials([
        sshUserPrivateKey(credentialsId: 'dodaxbuilder-rsa-dev01', keyFileVariable: 'ID_RSA'),
    ]) {
        sh """
        eval `ssh-agent -s`
        ssh-add -k ${ID_RSA}
        aws --version
        aws sts get-caller-identity
        terraform --version
        echo TF_WORKSPACE: ${TF_WORKSPACE}
        rm -rf ./terraform
        export TF_WORKSPACE=
        terraform init
        export TF_WORKSPACE=${DEPLOY_ENV}
        if [ \$(terraform workspace list | grep -c " ${TF_WORKSPACE}\$") -eq 0 ] ; then
            terraform workspace new ${TF_WORKSPACE}
        fi
        chmod 700 adduser.sh
        """
    }
}

def terraformPlan(String environment) {
    sh """
    terraform plan ${tf_vars} -out=${environment}.tfplan
    terraform show ./${environment}.tfplan > ${environment}-tfplan.txt
    """
    archiveArtifacts artifacts: '*-tfplan.txt', fingerprint: true
}