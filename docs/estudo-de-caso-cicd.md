# Roteiro Prático: CI/CD com AWS e GitHub Actions

Este documento descreve o passo a passo para a criação de uma infraestrutura completa de CI/CD na AWS utilizando o **Cloud Shell**, **VPC**, **RDS PostgreSQL**, **Elastic Beanstalk**, **S3** e **GitHub Actions**.

## 💻 Serviços AWS Utilizados

Para a construção desta arquitetura de CI/CD, são utilizados os seguintes serviços:

- **IAM (Identity and Access Management):** Gerenciamento de usuários, políticas de acesso, papéis (roles) e perfis de instância.
- **VPC (Virtual Private Cloud) & EC2:** Criação da rede privada virtual isolada, subnets públicas distribuídas em diferentes Zonas de Disponibilidade (AZs), tabelas de roteamento e Security Groups.
- **Elastic Beanstalk:** Serviço do tipo PaaS (Platform as a Service) para implantação, gerenciamento e escalonamento de aplicações web sobre instâncias EC2.
- **RDS (Relational Database Service):** Banco de dados relacional gerenciado (PostgreSQL), configurado dentro da VPC.
- **S3 (Simple Storage Service):** Armazenamento de objetos para retenção dos artefatos (arquivos `.jar`) e versionamento de deployments do Elastic Beanstalk.

## 🛠️ Etapa 1: Conexão e Secrets

Nesta etapa preparatória, são configuradas as credenciais de acesso e definido o ambiente de execução dos scripts da AWS CLI.

### 1. Criar Usuário no AWS IAM
1. Acesse o console da AWS e vá até o serviço **IAM**.
2. Crie um usuário com permissões programáticas necessárias para gerenciar e criar recursos de rede, RDS, Elastic Beanstalk e S3.
3. Gere uma **Access Key** e uma **Secret Access Key**.

### 2. Configurar Secrets no GitHub Repository
No seu repositório do GitHub (onde o workflow do GitHub Actions será executado):
1. Vá em **Settings** > **Secrets and variables** > **Actions**.
2. Adicione os seguintes segredos:
   - `AWS_ACCESS_KEY_ID`: Sua chave de acesso AWS.
   - `AWS_SECRET_ACCESS_KEY`: Sua chave secreta AWS.

### 3. Ambiente de Execução
Para executar os comandos de provisionamento da infraestrutura inicial, utilize o **[AWS Cloud Shell](https://console.aws.amazon.com/cloudshell/home)** diretamente no console web da AWS. Isso evita incompatividades de ambiente ou configurações pendentes da AWS CLI local.

## 🌐 Etapa 2: Provisionamento de Rede (VPC)

Nesta etapa, criamos a VPC, o Internet Gateway para acesso à internet, a tabela de roteamento e duas subnets públicas em Zonas de Disponibilidade (AZs) distintas.

### 1. Definir Identificador Único e Carregar Arquivo de Ambiente

> **Nota:** As variáveis de ambiente são salvas no arquivo `envrc` para facilitar o recarregamento (`source envrc`) caso a sessão do terminal expire.

```bash
# Definir o nome do ambiente e região
export ENV_NAME="pocdscatalog"
export AWS_REGION="sa-east-1"
export UNIQ="dsc${ENV_NAME}$(date +'%Y%m%d')"

# Criar e persistir as variáveis no arquivo envrc
echo export UNIQ=$UNIQ | tee envrc
echo export AWS_REGION=$AWS_REGION | tee -a envrc

cat envrc # shows environment variables
source envrc # loads environment variables if disconnected

# Testar autenticação e identidade na AWS
aws sts get-caller-identity
```

### 2. Criar a VPC - Virtual Private Cloud (rede)

```bash
export VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --query "Vpc.VpcId" \
    --output text)

echo export VPC_ID=$VPC_ID | tee -a envrc

# Nomear a VPC e habilitar suporte a DNS
aws ec2 create-tags --resources $VPC_ID \
    --tags Key=Name,Value="vpc-$UNIQ"
    
aws ec2 modify-vpc-attribute \
  --enable-dns-hostnames \
  --vpc-id $VPC_ID
  
aws ec2 modify-vpc-attribute \
  --enable-dns-support \
  --vpc-id $VPC_ID
```

### 3. Criar e Anexar o Internet Gateway

```bash
export IGW_ID=$(aws ec2 create-internet-gateway \
    --query "InternetGateway.InternetGatewayId" \
    --output text)
    
echo export IGW_ID=$IGW_ID | tee -a envrc

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID
```

### 4. Criar Tabela de Roteamento Pública e Rota Default

```bash
export RTB_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --query "RouteTable.RouteTableId" \
    --output text)

echo export RTB_ID=$RTB_ID | tee -a envrc

aws ec2 create-route \
    --route-table-id $RTB_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID
```

### 5. Criar Subnet Pública - Zona de Disponibilidade A

```bash
export CIDR_A=10.0.200.0/24

export AZ_A=$(aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[0].ZoneName'  \
  --output text)

export NET_A=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $CIDR_A \
    --availability-zone $AZ_A \
    --query "Subnet.SubnetId" \
    --output text)
    
echo export NET_A=$NET_A | tee -a envrc

# Associar tabela de roteamento e habilitar IP público automático
aws ec2 associate-route-table \
    --subnet-id $NET_A \
     --route-table-id $RTB_ID
     
aws ec2 modify-subnet-attribute  \
    --subnet-id $NET_A  \
    --map-public-ip-on-launch
```

### 6. Criar Subnet Pública - Zona de Disponibilidade B

```bash
export CIDR_B=10.0.201.0/24

export AZ_B=$(aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[1].ZoneName'  \
  --output text)

export NET_B=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $CIDR_B \
    --availability-zone $AZ_B \
    --query "Subnet.SubnetId" \
    --output text)
    
echo export NET_B=$NET_B | tee -a envrc

# Associar tabela de roteamento e habilitar IP público automático
aws ec2 associate-route-table \
    --subnet-id $NET_B \
     --route-table-id $RTB_ID
     
aws ec2 modify-subnet-attribute  \
    --subnet-id $NET_B  \
    --map-public-ip-on-launch
```

## 🗄️ Etapa 3: Banco de Dados Relacional (AWS RDS PostgreSQL)

```bash
source envrc

# Variáveis do RDS
export RDS_NETGRP=$UNIQ-netgrp
export RDS_NAME=$UNIQ-postgresql
export RDS_ROOT_USER=root
export RDS_ROOT_PASSWORD="SuaSenhaSeguraAqui123" # Altere para uma senha forte
export RDS_PORT=5432
export RDS_CIDR=0.0.0.0/0
export RDS_DB=dscatalogdb
export RDS_STORAGE=20
export RDS_INSTANCE=db.t3.micro
export RDS_ENGINE=postgres
export RDS_ENGINE_VERSION=14

echo export RDS_ROOT_USER=$RDS_ROOT_USER | tee -a envrc
echo export RDS_ROOT_PASSWORD=$RDS_ROOT_PASSWORD | tee -a envrc
echo export RDS_NETGRP=$RDS_NETGRP | tee -a envrc

# Security Group para o RDS
export RDS_SECG=$(aws ec2 create-security-group \
  --group-name dscatalog-rds-secgrp \
  --description "dscatalog-rds-secg" \
  --vpc-id $VPC_ID \
  --query "GroupId" \
  --output text)

echo export RDS_SECG=$RDS_SECG | tee -a envrc

export RDS_SECG_ID=$(aws ec2 describe-security-groups \
  --filter Name=vpc-id,Values=$VPC_ID Name=group-name,Values=dscatalog-rds-secgrp \
  --query 'SecurityGroups[*].[GroupId]' \
  --output text)

echo export RDS_SECG_ID=$RDS_SECG_ID | tee -a envrc

aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SECG \
  --protocol tcp \
  --port $RDS_PORT \
  --cidr $RDS_CIDR

# Subnet Group do RDS
aws rds create-db-subnet-group \
    --db-subnet-group-name $RDS_NETGRP \
    --db-subnet-group-description "dscatalog RDS Subnet Group" \
    --subnet-ids $NET_A $NET_B

# Instância RDS
export RDS_ID=$(aws rds create-db-instance \
  --db-name $RDS_DB  \
  --db-instance-identifier $RDS_NAME \
  --allocated-storage $RDS_STORAGE \
  --db-instance-class $RDS_INSTANCE \
  --engine $RDS_ENGINE \
  --engine-version $RDS_ENGINE_VERSION \
  --master-username $RDS_ROOT_USER \
  --master-user-password $RDS_ROOT_PASSWORD \
  --db-subnet-group-name  $RDS_NETGRP \
  --backup-retention-period 0 \
  --publicly-accessible \
  --vpc-security-group-ids $RDS_SECG \
  --query "DBInstance.DBInstanceIdentifier" \
  --output text)

echo export RDS_ID=$RDS_ID | tee -a envrc

# Aguardar provisionamento
aws rds wait db-instance-available --db-instance-identifier $RDS_ID && echo "Pronto"

# Obter String JDBC
export RDS_ENDPOINT=$(aws rds describe-db-instances  \
  --db-instance-identifier $RDS_ID  \
  --query "DBInstances[0].Endpoint.Address"  \
  --output text)
  
export RDS_PORT=$(aws rds describe-db-instances  \
  --db-instance-identifier $RDS_ID  \
  --query "DBInstances[0].Endpoint.Port"\
  --output text)

export RDS_JDBC=jdbc:postgresql://$RDS_ENDPOINT:$RDS_PORT/$RDS_DB  

echo export RDS_JDBC=$RDS_JDBC | tee -a envrc

# Verificando os recursos criados até aqui
cat envrc
```
> Administração do banco de dados
> - Conecte ao banco usando sua ferramenta favorita
> - Crie a estrutura das tabelas
> - Execute o seed do banco

## 🚀 Etapa 4: Infraestrutura Elastic Beanstalk e S3

```bash
source envrc

# Variáveis salvas
export EB_APP=${UNIQ}ebapp 
export EB_ENV=${UNIQ}ebenv
export EB_BUCKET=${UNIQ}versions
export EB_PROFILE=${UNIQ}insprofile
export EB_INSTANCE_TYPES=t3.micro
export EB_SPOT=false
export EB_TEMPLATE=${UNIQ}cfg

echo export EB_APP=$EB_APP | tee -a envrc
echo export EB_ENV=$EB_ENV | tee -a envrc
echo export EB_BUCKET=$EB_BUCKET | tee -a envrc
echo export EB_PROFILE=$EB_PROFILE | tee -a envrc
echo export EB_INSTANCE_TYPES=$EB_INSTANCE_TYPES | tee -a envrc
echo export EB_SPOT=$EB_SPOT | tee -a envrc
echo export EB_TEMPLATE=$EB_TEMPLATE | tee -a envrc

# Criar Aplicação EB
aws elasticbeanstalk create-application --application-name $EB_APP

# Criar Template de Configuração
# Obs: Verifique a versão suportada em: [https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html](https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html)
export EB_STACK="64bit Amazon Linux 2023 v4.12.8 running Corretto 11"

aws elasticbeanstalk create-configuration-template \
    --application-name $EB_APP \
    --template-name $EB_TEMPLATE \
    --solution-stack-name "$EB_STACK"

# IAM Roles do Instance Profile
wget https://raw.githubusercontent.com/enfarias/treinamento-implantacao-aws/main/scripts/eb/eb-ip-policy.json

wget https://raw.githubusercontent.com/enfarias/treinamento-implantacao-aws/main/scripts/eb/eb-ip-trust.json

export EB_ROLE=${UNIQ}ebrole
export EB_POLICYNAME=${UNIQ}policy

aws iam create-role --role-name $EB_ROLE --assume-role-policy-document file://eb-ip-trust.json

aws iam put-role-policy --role-name $EB_ROLE --policy-name $EB_POLICYNAME --policy-document file://eb-ip-policy.json

aws iam create-instance-profile --instance-profile-name $EB_PROFILE

aws iam add-role-to-instance-profile --instance-profile-name $EB_PROFILE --role-name $EB_ROLE

# Bucket S3 de Artefatos
aws s3 mb s3://$EB_BUCKET
```

## 🚀 Etapa 5 & 6: Build Zero Manual e Deploy Inicial

./mvnw clean package

> Subir o bundle (jar) para local público na nuvem (Github, S3, etc.)
> **Atenção:** confira se as variáveis dos recursos ainda estão em memória

```bash
source envrc

export BUNDLE_NAME=dscatalog-0.0.1-SNAPSHOT.jar
echo export BUNDLE_NAME=$BUNDLE_NAME | tee -a envrc

# Download do artefato de teste
wget https://github.com/enfarias/treinamento-implantacao-aws/releases/download/v0.0.1/dscatalog-0.0.1-SNAPSHOT.jar

export EB_VERSION="${UNIQ}v$(date +'%Y%m%d%H%M')"
export EB_VERSION_KEY=$EB_VERSION/dscatalog-0.0.1-SNAPSHOT.jar

echo export EB_VERSION=$EB_VERSION | tee -a envrc
echo export EB_VERSION_KEY=$EB_VERSION_KEY | tee -a envrc

# Upload para o S3 e Registro da Versão no EB
aws s3 cp --quiet dscatalog-0.0.1-SNAPSHOT.jar s3://$EB_BUCKET/$EB_VERSION_KEY

aws s3 ls s3://$EB_BUCKET/$EB_VERSION_KEY

aws elasticbeanstalk create-application-version \
    --application-name $EB_APP \
    --version-label $EB_VERSION \
    --source-bundle S3Bucket=$EB_BUCKET,S3Key=$EB_VERSION_KEY
```

## 🚀 Etapa 7 & 8: Provisionamento do Ambiente e Mapeamento de Configurações

```bash
source envrc

wget https://raw.githubusercontent.com/enfarias/treinamento-implantacao-aws/main/scripts/eb/options-config.json

# Substituição de variáveis no arquivo de opções do EB
sudo yum -y install gettext
envsubst < scripts/eb/options-config.json.env > options.txt
cat options.txt

# Verificar DNS e Criar Environment
export EB_CNAME="${UNIQ}ebcname$(date +'%Y%m%d%H%M')"

aws elasticbeanstalk check-dns-availability --cname-prefix $EB_CNAME

aws elasticbeanstalk create-environment \
    --cname-prefix $EB_CNAME \
    --application-name $EB_APP \
    --template-name $EB_TEMPLATE \
    --environment-name $EB_ENV \
    --version-label $EB_VERSION \
    --output json \
    --option-settings file://options.txt
```
> Acompanhe no dashboard do EB

## Etapa 9: Configurar variáveis de ambiente adicionais da aplicação Elastic Beanstalk

```bash
Configurations -> Software
  CLIENT_ID
  CLIENT_SECRET
  JWT_SECRET
  JWT_DURATION

Restart Application Servers
```
> **Nota:** as variáveis de conexão com o banco já foram definidas em --option-settings

## Etapa 10: Configurar environment secrets no Github

```bash
  EB_APP
  EB_BUCKET
  EB_ENV
  AWS_REGION
  BUNDLE_NAME
```

## 🧹 Teardown: Destruição Completa dos Recursos

> **Atenção:** Execute esses comandos ao encerrar os testes para evitar custos desnecessários na conta AWS.

```bash
source envrc

aws elasticbeanstalk terminate-environment --environment-name "$EB_ENV"
aws elasticbeanstalk delete-application --application-name "$EB_APP"
aws s3 rm "s3://$EB_BUCKET" --recursive
aws s3 rb "s3://$EB_BUCKET"

# Deletar banco RDS (Aguarde alguns minutos após o comando)
aws rds delete-db-instance --db-instance-identifier "$RDS_ID" --skip-final-snapshot
aws rds wait db-instance-deleted --db-instance-identifier "$RDS_ID"

# Destruição dos recursos de rede
aws rds delete-db-subnet-group --db-subnet-group-name "$RDS_NETGRP"
aws ec2 delete-security-group --group-id "$RDS_SECG_ID"
aws ec2 delete-subnet --subnet-id "$NET_A"
aws ec2 delete-subnet --subnet-id "$NET_B"
aws ec2  delete-route-table --route-table-id "$RTB_ID"
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
aws ec2 delete-vpc --vpc-id "$VPC_ID"
```
