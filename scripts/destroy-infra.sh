#!/bin/bash
set -e

if [ ! -f "envrc" ]; then
    echo "Aviso: Arquivo 'envrc' não encontrado. Certifique-se de que as variáveis estão configuradas ou edite o script."
    exit 1
fi

source envrc

echo "=== INICIANDO A DESTRUIÇÃO COMPLETA DOS RECURSOS (TEARDOWN) ==="

# 1. Terminar Ambiente e Aplicação Elastic Beanstalk
if [ ! -z "$EB_ENV" ]; then
    echo "Terminando ambiente Beanstalk: $EB_ENV..."
    aws elasticbeanstalk terminate-environment --environment-name "$EB_ENV" || true
    echo "Aguardando terminação do ambiente..."
    aws elasticbeanstalk wait environment-terminated --environment-name "$EB_ENV" || true
fi

if [ ! -z "$EB_APP" ]; then
    echo "Deletando aplicação Beanstalk: $EB_APP..."
    aws elasticbeanstalk delete-application --application-name "$EB_APP" --terminate-all-resources || true
fi

# 2. Limpar Bucket S3
if [ ! -z "$EB_BUCKET" ]; then
    echo "Esvaziando e deletando bucket S3: $EB_BUCKET..."
    aws s3 rm "s3://$EB_BUCKET" --recursive || true
    aws s3 rb "s3://$EB_BUCKET" || true
fi

# 3. Deletar Banco de Dados RDS
if [ ! -z "$RDS_ID" ]; then
    echo "Deletando instância RDS: $RDS_ID..."
    aws rds delete-db-instance --db-instance-identifier "$RDS_ID" --skip-final-snapshot || true
    echo "Aguardando exclusão do banco de dados..."
    aws rds wait db-instance-deleted --db-instance-identifier "$RDS_ID" || true
fi

if [ ! -z "$RDS_NETGRP" ]; then
    aws rds delete-db-subnet-group --db-subnet-group-name "$RDS_NETGRP" || true
fi

# 4. Remover Recursos de Rede (VPC, Subnets, Gateways)
if [ ! -z "$RDS_SECG" ]; then
    # Pega o ID atualizado do Security Group caso precise
    RDS_SECG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=dscatalog-rds-secgrp --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
    if [ ! -z "$RDS_SECG_ID" ]; then
        aws ec2 delete-security-group --group-id "$RDS_SECG_ID" || true
    fi
fi

if [ ! -z "$NET_A" ]; then
    aws ec2 delete-subnet --subnet-id "$NET_A" || true
fi

if [ ! -z "$NET_B" ]; then
    aws ec2 delete-subnet --subnet-id "$NET_B" || true
fi

if [ ! -z "$RTB_ID" ]; then
    aws ec2 delete-route-table --route-table-id "$RTB_ID" || true
fi

if [ ! -z "\(IGW_ID" ] && [ ! -z "\)VPC_ID" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "\(IGW_ID" --vpc-id "\)VPC_ID" || true
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" || true
fi

if [ ! -z "$VPC_ID" ]; then
    aws ec2 delete-vpc --vpc-id "$VPC_ID" || true
fi

# Limpar arquivo de ambiente local
rm -f envrc options.txt

echo "=== DESTRUIÇÃO CONCLUÍDA: NENHUM RECURSO RESIDUAL NA AWS ==="