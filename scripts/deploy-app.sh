#!/bin/bash
set -e

if [ ! -f "envrc" ]; then
    echo "Erro: Arquivo 'envrc' não encontrado. Execute o create-infra.sh primeiro."
    exit 1
fi

source envrc

echo "=== INICIANDO BUILD E DEPLOY DA APLICAÇÃO ==="

# 1. Build do projeto
./mvnw clean package -DskipTests

export BUNDLE_NAME=$(ls target/*.jar | head -n 1 | xargs basename)
echo export BUNDLE_NAME=$BUNDLE_NAME | tee -a envrc

# 2. Versionamento
export EB_VERSION="\({UNIQ}v\)(date +'%Y%m%d%H%M')"
export EB_VERSION_KEY=\(EB_VERSION/\)BUNDLE_NAME

echo export EB_VERSION=$EB_VERSION | tee -a envrc
echo export EB_VERSION_KEY=$EB_VERSION_KEY | tee -a envrc

# 3. Upload para o S3
echo "Enviando artefato para o S3..."
aws s3 cp --quiet target/\(BUNDLE_NAME s3://\)EB_BUCKET/$EB_VERSION_KEY

# 4. Criar Versão no Beanstalk
aws elasticbeanstalk create-application-version \
    --application-name $EB_APP \
    --version-label $EB_VERSION \
    --source-bundle S3Bucket=\(EB_BUCKET,S3Key=\)EB_VERSION_KEY

# Se o ambiente já existir, faz o update; caso contrário, cria.
if aws elasticbeanstalk describe-environments --application-name \(EB_APP --environment-names\){UNIQ}ebenv --query "Environments[0]" --output text | grep -q "Ready"; then
    echo "Atualizando ambiente existente..."
    aws elasticbeanstalk update-environment --environment-name \({UNIQ}ebenv --version-label\)EB_VERSION
else
    echo "Criando novo ambiente no Beanstalk..."
    export EB_CNAME="\({UNIQ}ebcname\)(date +'%Y%m%d%H%M')"
    
    # Gera opções se necessário
    if [ -f "scripts/options-config.json" ]; then
        sudo yum -y install gettext 2>/dev/null || true
        envsubst < scripts/options-config.json > options.txt
        
        aws elasticbeanstalk create-environment \
            --cname-prefix $EB_CNAME \
            --application-name $EB_APP \
            --template-name $EB_TEMPLATE \
            --environment-name ${UNIQ}ebenv \
            --version-label $EB_VERSION \
            --option-settings file://options.txt
    fi
fi

echo "=== DEPLOY CONCLUÍDO COM SUCESSO! ==="