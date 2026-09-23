# AWS Media Storage Architecture & CI/CD Automation

<p>
  <img src="https://img.shields.io/badge/Java-11%2F17-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white" alt="Java">
  <img src="https://img.shields.io/badge/Spring_Boot-2.4.4-6DB33F?style=for-the-badge&logo=spring-boot&logoColor=white" alt="Spring Boot">
  <img src="https://img.shields.io/badge/PostgreSQL-14-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/AWS-Elastic_Beanstalk-%23FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white" alt="AWS">
  <img src="https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?style=for-the-badge&logo=github-actions&logoColor=white" alt="GitHub Actions">
  <img src="https://img.shields.io/badge/Maven-Build-C71A36?style=for-the-badge&logo=apache-maven&logoColor=white" alt="Maven">
</p>

Este repositório contém os scripts de automação, arquivos de configuração e fluxos de trabalho para provisionamento de infraestrutura e implantação de aplicações em nuvem na **Amazon Web Services (AWS)**.

## 🏗️ Visão Geral da Arquitetura

O projeto estrutura um ambiente seguro e escalável na AWS utilizando:
* **Amazon VPC & Elastic Beanstalk**: Computação, rede e hospedagem de aplicações.
* **Amazon S3**: Armazenamento de objetos com políticas de segurança e acesso IAM.
* **AWS IAM**: Perfis de menor privilégio, políticas de confiança e configurações seguras de acesso.
* **AWS Lambda & Step Functions**: Processamento serverless de mídias e fluxos de orquestração.

## 📁 Estrutura do Projeto
```text
.
├── .github/
│   └── workflows/
│       ├── hello.yml                       # Workflow de teste/validação inicial
│       └── main-to-homolog.yml             # Workflow de CI/CD para o ambiente de homologação
├── backend/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/treinamento/dscatalog/
│   │   │   │   ├── components/             # Componentes utilitários
│   │   │   │   ├── config/                 # Configurações do Spring (Security, etc.)
│   │   │   │   ├── dto/                    # Data Transfer Objects
│   │   │   │   ├── entities/               # Entidades JPA / Modelos de Domínio
│   │   │   │   ├── repositories/           # Repositórios Spring Data JPA
│   │   │   │   ├── resources/              # Controllers / Endpoints REST
│   │   │   │   └── services/               # Regras de negócio
│   │   │   └── resources/
│   │   │       ├── application.properties  # Configuração padrão da aplicação
│   │   │       ├── application-dev.properties  # Configuração para desenvolvimento
│   │   │       ├── application-test.properties # Configuração para testes
│   │   │       └── data.sql                # Massa de dados inicial para o banco
│   │   └── test/
│   │       └── java/com/treinamento/dscatalog/
│   │           ├── repositories/           # Testes unitários de repositórios
│   │           ├── resources/              # Testes de integração/controladores
│   │           ├── services/               # Testes unitários de serviços
│   │           └── tests/                  # Classes auxiliares de teste
│   └── pom.xml                             # Configuração de dependências e build Maven
├── docs/
│   ├── postman/
│   │   ├── DSCatalog Aula.postman_collection.json      # Coleção de requisições da API
│   │   └── DSCatalog env.postman_environment.json    # Variáveis de ambiente do Postman
│   ├── backend-postman.md                  # Guia de arquitetura do backend e uso do Postman
│   └── estudo-de-caso-cicd.md              # Documentação detalhada do estudo de caso
├── scripts/
│   ├── eb/
│   │   ├── eb-ip-policy.json               # Política de segurança e IP do Elastic Beanstalk
│   │   ├── eb-ip-trust.json                # Política de confiança IAM para o Elastic Beanstalk
│   │   └── options-config.json             # Opções e variáveis de configuração do Beanstalk
│   ├── create-infra.sh                     # Provisiona a infraestrutura na AWS
│   ├── deploy-app.sh                       # Automatiza o deploy da aplicação
│   ├── destroy-infra.sh                    # Remove os recursos de forma segura
│   └── dscatalog.sql                       # Script SQL geral do banco de dados
└── README.md
```

## 🚀 Como Começar

### Pré-requisitos
* **AWS CLI** instalado e configurado com credenciais adequadas.
* **Git** para controle de versão.
* **Terminal Bash** (Linux, macOS ou Windows via WSL / Git Bash).

### Guia Rápido: Executando os Scripts de Automação

1. **Clone o repositório:**
   ```bash
   git clone [https://github.com/enfarias/aws-media-storage-architecture.git](https://github.com/enfarias/aws-media-storage-architecture.git)
   cd aws-media-storage-architecture
   ```

2. **Conceda permissão de execução aos scripts:**
   ```bash
    chmod +x scripts/*.sh
   ```
   
2. **Provisionar a Infraestrutura:**
   
   Execute o script de criação para configurar os recursos na nuvem:
   ```bash
    ./scripts/create-infra.sh
   ```
   
4. **Fazer o Deploy da Aplicação:**
   
   Execute o script de deploy para enviar sua aplicação:
   ```bash
    ./scripts/deploy-app.sh
   ```
## 🧹 Limpeza do Ambiente

Para evitar cobranças indesejadas na sua conta AWS, você pode destruir os recursos criados executando:
```bash
./scripts/destroy-infra.sh
``` 
