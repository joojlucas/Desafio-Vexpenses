# Desafio-Vexpenses
Desafio online do processo seletivo de estágio DevOps da Vexpenses: Aprimoramento de código Terraform.

# Descrição Técnica - Infraestrutura AWS com Terraform

## Visão Geral
Este projeto define e fornece uma infraestrutura básica na AWS utilizando Terraform, criando uma instância EC2 Debian 12 dentro de uma VPC personalizada. O código automatiza a criação de redes, segurança e disposição de máquina virtual, garantindo uma configuração mínima necessária para um ambiente funcional.

O código realiza as seguintes operações:
- **Configuração do Provedor AWS**: Define a região como `us-east-1`.
- **Definição de Variáveis**: Permite a personalização dos nomes dos recursos com projeto e candidato.
- **Criação de uma Chave SSH**: Gera um par de chaves RSA para acesso à instância.
- **Fornecimento da Infraestrutura de Rede**:
  - VPC personalizada com suporte a DNS.
  - Sub-rede pública dentro da VPC.
  - Internet Gateway para permitir acesso externo.
  - Tabela de rotas conectando a sub-rede ao gateway da internet.
  - Associação da tabela de rotas à sub-rede.
- **Configuração de Segurança**:
  - Grupo de segurança permitindo conexões SSH (porta 22) de qualquer lugar e liberando tráfego de saída irrestrito.
- **Criação de Instância EC2**:
  - Seleção automática da AMI Debian 12 mais recente.
  - Criação de uma instância t2.micro com IP público.
  - Associação da instância ao grupo de segurança.
  - Configuração do disco root com 20GB SSD (gp2).
  - Script de inicialização via `user_data` para atualização do sistema.
- **Saídas da Infraestrutura**:
  - Chave privada SSH para acessar a instância.
  - IP público da instância para conexão remota.

## Requisitos
Antes de executar o código, é necessário:
- Conta AWS configurada com permissões adequadas.
- AWS CLI instalado e autenticado.
- Terraform instalado (>= v1.0.0).

## Detalhamento dos Recursos Criados

### 1. Provedor AWS
```hcl
provider "aws" {
  region = "us-east-1"
}
```
Define variáveis para personalização dos nomes dos recursos.

### 2. Variáveis
```hcl
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}
```
Define variáveis para personalização dos nomes dos recursos.

### 3. Geração de Chave SSH
```hcl
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
```
Cria uma chave privada RSA para acesso à instância EC2.

### 4. Infraestrutura de Rede
#### 4.1. Criação da VPC
```hcl
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}
```
Cria uma VPC com suporte a DNS.

#### 4.2. Sub-rede
```hcl
resource "aws_subnet" "main_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}
```
Cria uma sub-rede pública dentro da VPC.

#### 4.3. Internet Gateway
```hcl
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}
```
Habilita o acesso à internet.

#### 4.4. Tabela de Rotas
```hcl
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
}
```
Define regras de roteamento para permitir tráfego externo.

### 5. Grupo de Segurança
```hcl
resource "aws_security_group" "main_sg" {
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```
Permite **acesso SSH de qualquer lugar** e **todo o tráfego de saída**.

### 6. Instância EC2
#### 6.1. Seleção da AMI
```hcl
data "aws_ami" "debian12" {
  most_recent = true
  filter {
    name = "name"
    values = ["debian-12-amd64-*"]
  }
}
```
Busca a **AMI mais recente do Debian 12**.

#### 6.2. Provisionamento da Instância
```hcl
resource "aws_instance" "debian_ec2" {
  ami = data.aws_ami.debian12.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.main_subnet.id
  security_groups = [aws_security_group.main_sg.name]
  associate_public_ip_address = true
  root_block_device {
    volume_size = 20
    volume_type = "gp2"
    delete_on_termination = true
  }
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              EOF
}
```
Cria uma **instância EC2 Debian 12** com 20GB de armazenamento e atualizações automáticas via user_data.

### 7. saídas
```hcl
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value = tls_private_key.ec2_key.private_key_pem
  sensitive = true
}
```
Exibe a **chave privada SSH** e o **IP público** da instância.

### Observações Importantes
- **Abertura de Porta SSH**: O grupo de segurança permite conexões SSH de qualquer lugar (0.0.0.0/0), o que **não é seguro**. Para produção, restrinja a um IP específico.
- **Segurança da Chave Privada**: O Terraform exibe a chave nos outputs; **um erro de segurança gravíssimo**.

### Conclusão
Este projeto fornece uma infraestrutura básica para hospedar uma instância EC2 Debian 12 de forma segura e automatizada. Ele pode ser expandido com balanceadores de carga, bancos de dados e outras configurações avançadas.



## Melhorias Implementadas
### 1. Segurança Aprimorada
#### 1.1. Restrição do Acesso SSH
Antes: O código permitia conexões SSH de qualquer IP (0.0.0.0/0), o que representa um risco de segurança.
Agora: O acesso SSH está restrito a um IP específico.
```hcl
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Segurança aprimorada para SSH e HTTP"
  vpc_id      = aws_vpc.main_vpc.id

  # Permitir apenas SSH do IP autorizado
  ingress {
    description = "Allow SSH from authorized IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_ip]
  }

  # Permitir acesso HTTP para Nginx
  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir saída irrestrita
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```
#### 1.2. Justificativa
- A **restrição do SSH** protege contra ataques de força bruta e acessos não autorizados.
- Abertura da porta 80 permite acesso ao servidor web Nginx.

### 2. Automatização da Instalação do Nginx
Antes: O *user_data* apenas realizava atualização do sistema.
Agora: Ele instala e inicia o Nginx automaticamente.
```hcl
user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF
```
#### 2.1. Justificativa
- Facilita a configuração do servidor web ao instalar e iniciar o Nginx automaticamente.
- Garante que o serviço seja iniciado após reinicializações com *systemctl enable nginx*.

### 3. Modularidade
- Agora é possível mudar o tipo da instância (*instance_type*), tamanho do disco (*disk_size*), zona de disponibilidade (*az*), **CIDR da VPC/Subnet** sem modificar o código principal.

### 4. Performance & Custo
- Volume alterado para gp3, que tem melhor performance e menor custo em comparação ao gp2.

### 5. Melhoria na Manutenção
- Código mais legível, comentado, flexível e fácil de modificar.

## Conclusão
Essas mudanças tornam a infraestrutura mais flexível, escalável e econômica, sendo recomendadas para qualquer ambiente que precise de segurança, eficiência e rápida configuração.
