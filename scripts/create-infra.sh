#!/bin/bash
set -e

echo "=== INICIANDO O PROVISIONAMENTO DA INFRAESTRUTURA NA AWS ==="

# 1. Variáveis e Identificador Único
export ENV_NAME="pocdscatalog"
export AWS_REGION="sa-east-1"
export UNIQ="dsc\({ENV_NAME}\)(date +'%Y%m%d')"

echo export ENV_NAME=$ENV_NAME | tee envrc
echo export AWS_REGION=$AWS_REGION | tee -a envrc
echo export UNIQ=$UNIQ | tee -a envrc

aws sts get-caller-identity

# 2. Criar a VPC
echo "Criando VPC..."
export VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query "Vpc.VpcId" --output text)
echo export VPC_ID=$VPC_ID | tee -a envrc

aws ec2 create-tags --resources \(VPC_ID --tags Key=Name,Value="vpc-\)UNIQ"
aws ec2 modify-vpc-attribute --enable-dns-hostnames --vpc-id $VPC_ID
aws ec2 modify-vpc-attribute --enable-dns-support --vpc-id $VPC_ID

# 3. Internet Gateway
echo "Criando e anexando Internet Gateway..."
export IGW_ID=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
echo export IGW_ID=$IGW_ID | tee -a envrc
aws ec2 attach-internet-gateway --vpc-id \(VPC_ID --internet-gateway-id\)IGW_ID

# 4. Tabela de Roteamento Pública
echo "Criando Tabela de Roteamento..."
export RTB_ID=\((aws ec2 create-route-table --vpc-id\)VPC_ID --query "RouteTable.RouteTableId" --output text)
echo export RTB_ID=$RTB_ID | tee -a envrc
aws ec2 create-route --route-table-id \(RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id\)IGW_ID

# 5. Subnets Públicas (AZ A e AZ B)
echo "Criando Subnets Públicas..."
export AZ_A=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text)
export NET_A=\((aws ec2 create-subnet --vpc-id\)VPC_ID --cidr-block 10.0.200.0/24 --availability-zone $AZ_A --query "Subnet.SubnetId" --output text)
echo export NET_A=$NET_A | tee -a envrc
aws ec2 associate-route-table --subnet-id \(NET_A --route-table-id\)RTB_ID
aws ec2 modify-subnet-attribute --subnet-id $NET_A --map-public-ip-on-launch

export AZ_B=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text)
export NET_B=\((aws ec2 create-subnet --vpc-id\)VPC_ID --cidr-block 10.0.201.0/24 --availability-zone $AZ_B --query "Subnet.SubnetId" --output text)
echo export NET_B=$NET_B | tee -a envrc
aws ec2 associate-route-table --subnet-id \(NET_B --route-table-id\)RTB_ID
aws ec2 modify-subnet-attribute --subnet-id $NET_B --map-public-ip-on-launch

# 6. Banco de Dados RDS PostgreSQL
echo "Configurando Banco de Dados RDS..."
export RDS_NETGRP=$UNIQ-netgrp
export RDS_NAME=$UNIQ-postgresql
export RDS_ROOT_USER=root
export RDS_ROOT_PASSWORD="SuaSenhaSeguraAqui123"
export RDS_PORT=5432
export RDS_DB=dscatalogdb

echo export RDS_ROOT_USER=$RDS_ROOT_USER | tee -a envrc
echo export RDS_ROOT_PASSWORD=$RDS_ROOT_PASSWORD | tee -a envrc
echo export RDS_NETGRP=$RDS_NETGRP | tee -a envrc

export RDS_SECG=\((aws ec2 create-security-group --group-name dscatalog-rds-secgrp --description "dscatalog-rds-secg" --vpc-id\)VPC_ID --query "GroupId" --output text)
echo export RDS_SECG=$RDS_SECG | tee -a envrc

aws ec2 authorize-security-group-ingress --group-id \(RDS_SECG --protocol tcp --port\)RDS_PORT --cidr 0.0.0.0/0

aws rds create-db-subnet-group --db-subnet-group-name \(RDS_NETGRP --db-subnet-group-description "dscatalog RDS Subnet Group" --subnet-ids\)NET_A $NET_B

export RDS_ID=$(aws rds create-db-instance \
  --db-name $RDS_DB \
  --db-instance-identifier $RDS_NAME \
  --allocated-storage 20 \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 14 \
  --master-username $RDS_ROOT_USER \
  --master-user-password $RDS_ROOT_PASSWORD \
  --db-subnet-group-name $RDS_NETGRP \
  --backup-retention-period 0 \
  --publicly-accessible \
  --vpc-security-group-ids $RDS_SECG \
  --query "DBInstance.DBInstanceIdentifier" \
  --output text)

echo export RDS_ID=$RDS_ID | tee -a envrc

# 7. Elastic Beanstalk e S3
echo "Criando Aplicação Elastic Beanstalk e Bucket S3..."
export EB_APP=${UNIQ}ebapp
export EB_BUCKET=${UNIQ}versions
export EB_TEMPLATE=${UNIQ}cfg

echo export EB_APP=$EB_APP | tee -a envrc
echo export EB_BUCKET=$EB_BUCKET | tee -a envrc
echo export EB_TEMPLATE=$EB_TEMPLATE | tee -a envrc

aws elasticbeanstalk create-application --application-name $EB_APP
aws elasticbeanstalk create-configuration-template --application-name \(EB_APP --template-name\)EB_TEMPLATE --solution-stack-name "64bit Amazon Linux 2023 v4.12.8 running Corretto 11"

aws s3 mb s3://$EB_BUCKET

echo "Aguardando o RDS ficar disponível (isso pode levar alguns minutos)..."
aws rds wait db-instance-available --db-instance-identifier $RDS_ID

echo "=== INFRAESTRUTURA CRIADA COM SUCESSO! ==="