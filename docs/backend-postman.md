# Documentação do Backend e Postman - DSCatalog

Este guia descreve a estrutura do backend da aplicação **DSCatalog** (desenvolvida em Java com Spring Boot) e orienta sobre como utilizar a coleção de requisições do Postman para testar os endpoints da API.

## 1. Visão Geral do Projeto Backend

O projeto é uma API RESTful desenvolvida com **Spring Boot 2.4.4** estruturada em camadas, utilizando **Spring Data JPA** para acesso a dados e **Spring Security com OAuth2 (JWT)** para autenticação e autorização.

### Tecnologias e Dependências Principais (`pom.xml`)
* **Java Version:** 11
* **Spring Boot Starters:** Web, Data JPA, Validation, Test
* **Segurança:** Spring Security OAuth2 Autoconfigure
* **Bancos de Dados:** H2 Database (para ambiente de testes em memória) e PostgreSQL (para ambiente de desenvolvimento/produção)

## 2. Configurações de Ambiente

O projeto possui perfis de configuração isolados em `src/main/resources`:

* **`application-test.properties`**: Utiliza o banco de dados em memória **H2** (`jdbc:h2:mem:testdb`) com o console habilitado em `/h2-console`.
* **`application-dev.properties`**: Configurado para rodar com **PostgreSQL** local (`jdbc:postgresql://localhost:5432/dscatalog`).

## 3. Endpoints Disponíveis

A API está dividida nos seguintes recursos principais:

### 🔐 Autenticação (`/oauth/token`)
* **POST**: Realiza a autenticação via credenciais de cliente (`client-id` e `client-secret`) e do usuário (`username` e `password`), retornando o token JWT de acesso.

### 🏷️ Categorias (`/categories`)
* `GET /categories`: Retorna uma página de categorias de forma paginada.
* `GET /categories/{id}`: Busca uma categoria específica por ID.
* `POST /categories`: Cria uma nova categoria *(Requer perfil ADMIN ou OPERATOR)*.
* `PUT /categories/{id}`: Atualiza uma categoria existente *(Requer perfil ADMIN ou OPERATOR)*.
* `DELETE /categories/{id}`: Remove uma categoria por ID *(Requer perfil ADMIN ou OPERATOR)*.

### 📦 Produtos (`/products`)
* `GET /products`: Retorna produtos paginados (com suporte a filtros por nome e categoria).
* `GET /products/{id}`: Busca um produto específico por ID.
* `POST /products`: Cadastra um novo produto *(Requer autenticação)*.
* `PUT /products/{id}`: Atualiza os dados de um produto *(Requer autenticação)*.
* `DELETE /products/{id}`: Remove um produto por ID *(Requer autenticação)*.

### 👥 Usuários (`/users`)
* `GET /users`: Retorna uma lista paginada de usuários *(Requer perfil ADMIN)*.
* `GET /users/{id}`: Busca um usuário por ID *(Requer perfil ADMIN)*.
* `POST /users`: Cadastra um novo usuário com validação de dados e regras
* `PUT /users/{id}`: Atualiza os dados de um usuário *(Requer perfil ADMIN)*.
* `DELETE /users/{id}`: Remove um usuário por ID *(Requer perfil ADMIN)*.

* ## 4. Como Importar e Usar o Postman

Para testar os endpoints documentados, utilize os arquivos localizados na pasta `\docs\postman`:

1. **Coleção de Requisições**: `DSCatalog Aula.postman_collection.json`
2. **Variáveis de Ambiente**: `DSCatalog env.postman_environment.json`

### Passos para configuração:
1. Abra o **Postman**.
2. Clique em **Import** e selecione os dois arquivos JSON (`.postman_collection.json` e `.postman_environment.json`).
3. No canto superior direito do Postman, selecione o ambiente ativo **"DSCatalog env"**.
4. Verifique o valor da variável **`{{host}}`**: para testes locais, mantenha apontando para `http://localhost:8080`; caso esteja testando com a aplicação em **deploy na nuvem (AWS)**, lembre-se de atualizar o valor da variável **`{{host}}`** para o DNS ou IP público correspondente
5. Execute primeiro a requisição **Login** dentro da pasta `Auth`. O script de teste automatizado capturará o token retornado e o salvará na variável de ambiente `{{token}}` para autenticar as próximas requisições protegidas automaticamente.
