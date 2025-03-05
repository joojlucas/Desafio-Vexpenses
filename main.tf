provider "aws" {
  region = "us-east-1" # Define a região da AWS
}

# Variáveis para personalização do projeto e candidato
variable "projeto" {
  description = "Desafio Terraform"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "JoaoLucasRodrigues"
}

variable "allowed_ssh_ip" {
  description = "IP autorizado para conexões SSH"
  type        = string
  default     = "YOUR_IP/32"  # Substituir pelo seu IP para maior segurança
}

# Variáveis para maior flexibilidade
variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro"
}

variable "disk_size" {
  description = "Tamanho do volume da instância (GB)"
  type        = number
  default     = 20
}

variable "az" {
  description = "Zona de disponibilidade"
  type        = string
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR da Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Criação de chave SSH para acesso à instância EC2
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Criação da VPC principal
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}

# Criando uma subnet dentro da VPC
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.subnet_cidr
  availability_zone = var.az

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}

# Criando um Internet Gateway para permitir acesso à internet
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

# Criando uma tabela de rotas para permitir tráfego externo
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Define que qualquer tráfego pode sair pela internet
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

# Associação da tabela de rotas à subnet criada
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}

# Criando um grupo de segurança com regras de acesso controladas
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Segurança aprimorada para SSH e HTTP"
  vpc_id      = aws_vpc.main_vpc.id

  # Permitir acesso SSH apenas do IP especificado
  ingress {
    description = "Allow SSH from authorized IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_ip]
  }

  # Permitir tráfego HTTP para acesso ao Nginx
  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir todo o tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Obtendo a AMI mais recente do Debian 12
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}

# Criando uma instância EC2 com Debian 12 e Nginx pré-instalado
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.disk_size
    volume_type           = "gp3"  # Melhor custo e desempenho
    delete_on_termination = true
  }

  # Script de inicialização para instalar e iniciar o Nginx automaticamente
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

# Saída da chave privada para acesso à instância (uso sensível, deve ser protegida)
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

# Saída do IP público da instância EC2
output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
