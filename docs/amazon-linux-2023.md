# Implantação e Automação do Amazon Linux 2023 (AL2023) no WSL 2

Guia técnico detalhado para provisionar o **Amazon Linux 2023 (AL2023)** no **Windows Subsystem for Linux (WSL 2)** a partir da imagem oficial publicada no **Amazon ECR Public** (`public.ecr.aws/amazonlinux/amazonlinux:2023`), com `/etc/fstab` corrigido, `systemd`, **OpenSSH Server**, pacote nativo `awscli-2` e ferramentas de administração Enterprise Linux.

---

## 1. Contexto Técnico

O **Amazon Linux 2023** é a distribuição Linux padrão da AWS (suportada até junho de 2029), baseada no ecossistema Fedora com gerenciador de pacotes **`dnf`**, repositórios versionados de forma determinística e integração nativa com serviços AWS. Como não está disponível na Microsoft Store via `wsl --list --online`, utilizamos a extração de `rootfs.tar` via Docker seguida de `wsl --import`.

---

## 2. Passo a Passo Manual

### Etapa 1: Extração do `rootfs.tar` via Docker (Ubuntu WSL 2)

```bash
mkdir -p /mnt/c/WSL/amazonlinux-2023/disk

docker pull public.ecr.aws/amazonlinux/amazonlinux:2023
docker create --name temp-al2023 public.ecr.aws/amazonlinux/amazonlinux:2023
docker export temp-al2023 -o /mnt/c/WSL/amazonlinux-2023/rootfs.tar
docker rm temp-al2023
```

### Etapa 2: Registro no WSL 2 (PowerShell)

```powershell
wsl --import amazonlinux-2023 C:\WSL\amazonlinux-2023\disk C:\WSL\amazonlinux-2023\rootfs.tar --version 2
Remove-Item C:\WSL\amazonlinux-2023\rootfs.tar
```

### Etapa 3: Bootstrap Interno, `/etc/fstab`, AWS CLI v2 e OpenSSH Server

Acesse a instância como `root`:

```powershell
wsl -d amazonlinux-2023 -u root
```

Execute os comandos abaixo manualmente dentro da instância:

```bash
# Cria /etc/fstab (ausente na imagem OCI do AL2023) para evitar falha no mount -a do WSL
printf "# /etc/fstab: static file system information for WSL 2\n" > /etc/fstab
chmod 644 /etc/fstab

dnf update -y

# A flag --allowerasing resolve o conflito nativo entre curl-minimal e curl no AL2023
dnf install -y --allowerasing \
  systemd sudo passwd shadow-utils bash-completion vim-enhanced curl which less \
  procps-ng iproute iputils bind-utils net-tools openssh-server openssh-clients \
  man-db file tree zip unzip bzip2 xz patch rsync lsof time hostname \
  wget tcpdump traceroute nmap-ncat chrony cronie at logrotate \
  e2fsprogs xfsprogs dosfstools parted lvm2 acl policycoreutils \
  awscli-2

# Criação do usuário padrão no grupo wheel
useradd -m -G wheel -s /bin/bash labuser
passwd labuser

# Configuração do OpenSSH Server na porta 2223
ssh-keygen -A
mkdir -p /etc/ssh/sshd_config.d /run/sshd
cat <<EOF > /etc/ssh/sshd_config.d/99-wsl-remote.conf
Port 2223
ListenAddress 0.0.0.0
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin no
AuthorizedKeysFile .ssh/authorized_keys
EOF

sshd -t && systemctl enable sshd
```

### Etapa 4: Configuração do `/etc/wsl.conf` e Reinicialização

```bash
cat <<EOF > /etc/wsl.conf
[boot]
systemd=true

[network]
hostname=amazonlinux-2023
generateHosts=true

[user]
default=labuser
EOF
exit
```

No **PowerShell**, encerre e reinicie a instância:

```powershell
wsl --terminate amazonlinux-2023
wsl -d amazonlinux-2023
```

---

## 4. Particularidades e Troubleshooting do Amazon Linux 2023 no WSL 2

* **Erro `wsl: Processing /etc/fstab with mount -a failed` e `Failed to translate 'C:\...'`:**
  * **Causa:** A imagem OCI `amazonlinux:2023` vem sem o arquivo `/etc/fstab`. Durante o boot, o WSL executa `mount -a`, falha por ausência do arquivo, aborta a montagem do drive `C:\` em `/mnt/c` e falha ao traduzir as variáveis de ambiente `PATH` herdadas do Windows.
  * **Solução:** Criar um `/etc/fstab` vazio (`printf "# /etc/fstab\n" > /etc/fstab`) e reiniciar a instância (`wsl --terminate amazonlinux-2023`).
  * **Isolamento opcional de PATH:** Caso não deseje herdar binários do Windows no `$PATH` do Linux, adicione `[interop]` com `appendWindowsPath=false` no `/etc/wsl.conf`.
* **Conflito `curl-minimal` vs. `curl`:** A imagem OCI `amazonlinux:2023` vem pré-instalada com `curl-minimal`. Ferramentas que requerem o pacote `curl` completo geram conflito no `dnf`. Use `--allowerasing` na instalação de pacotes.
* **AWS CLI v2 Nativo (`awscli-2`):** Diferente de outras distribuições Enterprise Linux, no AL2023 o `awscli-2` é mantido diretamente no repositório oficial `amazonlinux` e atualizado via `dnf update`.
* **Tag `2023` vs. `2023-minimal`:** Evite a tag `2023-minimal` para WSL 2, pois utiliza `microdnf` e omite bibliotecas básicas de shell interativo.

---

## 5. Checagem Final de Auditoria

Após reiniciar (`wsl --terminate amazonlinux-2023`), execute o script de checagem final ou valide manualmente:

```bash
bash /mnt/c/WSL/wsl2-enterprise-linux-lab/scripts/check-wsl-el.sh labuser 2223

mountpoint /mnt/c                   # /mnt/c is a mountpoint
whoami && pwd                       # labuser | /home/labuser
grep PRETTY_NAME /etc/os-release    # PRETTY_NAME="Amazon Linux 2023.x"
ps -p 1 -o pid,comm                 # 1 systemd
systemctl is-active sshd            # active
aws --version                       # aws-cli/2.x Python/3.x Linux/6.x
ssh -p 2223 labuser@localhost "hostname && uptime"
```

---

*Transparência de IA: Este projeto foi estruturado e revisado com auxílio de ferramentas de IA e testado manualmente pelo autor.*
