# Validação do Amazon Linux 2027 (Preview) no WSL 2

Guia prático e manual para provisionar e validar o **Amazon Linux 2027 (AL2027 Preview)** no **WSL 2** a partir do arquivo oficial `.docker.tar.xz` publicado no CDN da AWS (`cdn-al2027.amazonlinux.com`).

> **Por que manual?** Logo após `wsl --import`, imagens OCI mínimas do Amazon Linux ainda não possuem `/etc/fstab`, `systemd`, usuário comum ou `sshd` — por isso o próprio `/mnt/c` pode não estar montado no primeiro boot. O passo a passo abaixo resolve tudo linha a linha dentro da instância e usa `scripts/check-wsl-el.sh` para a checagem final.

---

## Contexto Técnico

O **Amazon Linux 2027 (AL2027)** é a próxima geração da família Amazon Linux mantida pela AWS (também derivada do ecossistema **Fedora** / RPM / `dnf`), atualmente disponibilizada em **Preview** via CDN oficial da AWS (`cdn-al2027.amazonlinux.com`) para validação antecipada de pacotes e compatibilidade antes do lançamento geral (GA).

- **Documentação e fontes oficiais:** [amazonlinux.com](https://amazonlinux.com/) · [CDN AL2027 Preview](https://cdn-al2027.amazonlinux.com/) · [Microsoft WSL Custom Distro](https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro)

---

## 1. Passo a Passo Manual

### Etapa 1: Baixar e converter `.docker.tar.xz` para `rootfs.tar` (Ubuntu WSL 2)

> **Atenção:** o arquivo `.docker.tar.xz` é um pacote de camadas Docker (`manifest.json` + blobs), **não** um `rootfs.tar` direto. Por isso é necessário fazer `docker load` seguido de `docker export`.

```bash
mkdir -p /mnt/c/WSL/amazonlinux-2027/disk

curl -fsSLO https://cdn-al2027.amazonlinux.com/os-images/2027.0.20261109.0/container/al2027-preview-container-2027.0.20261109.0-x86_64.docker.tar.xz
curl -fsSLO https://cdn-al2027.amazonlinux.com/os-images/2027.0.20261109.0/container/SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing

LOADED_IMAGE=$(docker load -i al2027-preview-container-2027.0.20261109.0-x86_64.docker.tar.xz | awk '/Loaded image/{print $NF}')
docker create --name temp-al2027 "$LOADED_IMAGE"
docker export temp-al2027 -o /mnt/c/WSL/amazonlinux-2027/rootfs.tar
docker rm temp-al2027
```

### Etapa 2: Importar no WSL 2 (PowerShell)

```powershell
wsl --import amazonlinux-2027 C:\WSL\amazonlinux-2027\disk C:\WSL\amazonlinux-2027\rootfs.tar --version 2
Remove-Item C:\WSL\amazonlinux-2027\rootfs.tar
```

### Etapa 3: Configuração Interna (dentro do `amazonlinux-2027` como `root`)

Entre na instância:

```powershell
wsl -d amazonlinux-2027 -u root
```

Execute os comandos abaixo linha a linha dentro do AL2027:

```bash
# 1. Cria /etc/fstab (evita falha no mount -a e garante montagem de /mnt/c)
printf "# /etc/fstab: static file system information for WSL 2\n" > /etc/fstab
chmod 644 /etc/fstab

# 2. Atualiza pacotes e instala base + systemd + langpacks (evita erros de locale na inicialização)
dnf update -y
dnf install -y --allowerasing \
  systemd sudo passwd shadow-utils bash-completion vim-enhanced \
  glibc-langpack-en glibc-langpack-pt \
  which less hostname time lsof rsync man-db \
  procps-ng file tree zip unzip bzip2 xz patch curl \
  iproute iputils bind-utils net-tools openssh-server openssh-clients \
  wget tcpdump traceroute nmap-ncat chrony cronie logrotate \
  e2fsprogs xfsprogs dosfstools parted lvm2 acl policycoreutils

# 3. Cria usuário padrão com sudo (grupo wheel) e diretório .ssh
useradd -m -G wheel -s /bin/bash labuser
passwd labuser
mkdir -p /home/labuser/.ssh
touch /home/labuser/.ssh/authorized_keys
chown -R labuser:labuser /home/labuser/.ssh
chmod 700 /home/labuser/.ssh
chmod 600 /home/labuser/.ssh/authorized_keys

# 4. Configura OpenSSH Server em 127.0.0.1:2224
ssh-keygen -A
mkdir -p /etc/ssh/sshd_config.d /run/sshd
cat <<'EOF' > /etc/ssh/sshd_config.d/99-wsl-remote.conf
Port 2224
ListenAddress 127.0.0.1
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin no
AuthorizedKeysFile .ssh/authorized_keys
EOF
chmod 644 /etc/ssh/sshd_config.d/99-wsl-remote.conf
sshd -t && systemctl enable sshd

# 5. Habilita systemd, hostname padrão e usuário padrão no /etc/wsl.conf
cat <<'EOF' > /etc/wsl.conf
[boot]
systemd=true

[network]
hostname=amazonlinux-2027
generateHosts=true

[user]
default=labuser
EOF
exit
```

### Etapa 4: Reiniciar para ativar `systemd` e `/mnt/c` (PowerShell)

```powershell
wsl --terminate amazonlinux-2027
wsl -d amazonlinux-2027
```

---

## 2. Troubleshooting Validado na Prática

* **Erros de locale (`setlocale: LC_ALL: cannot change locale`) na inicialização:** imagens OCI mínimas trazem apenas `C.UTF-8` e omitem pacotes de idioma, gerando avisos quando o WSL/SSH herda `en_US.UTF-8` ou `pt_BR.UTF-8`. A solução validada no AL2027 Preview é instalar:
  ```bash
  sudo dnf install -y glibc-langpack-en glibc-langpack-pt
  ```

---

## 3. Checagem Final de Validação

Com o `systemd` ativo e `/mnt/c` montado, execute o script de auditoria:

```bash
bash /mnt/c/WSL/wsl2-enterprise-linux-lab/scripts/check-wsl-el.sh labuser 2224
```

Ou valide manualmente:

```bash
cat /etc/os-release                 # Confirma Amazon Linux 2027
uname -r                            # Kernel WSL 2
ps -p 1 -o pid,comm                 # 1 systemd
mountpoint /mnt/c                   # /mnt/c is a mountpoint
systemctl is-active sshd            # active
dnf --version                       # Versão do DNF no AL2027
ssh -p 2224 labuser@localhost "hostname && cat /etc/system-release"
```

---

*Transparência de IA: Este projeto foi estruturado e revisado com auxílio de ferramentas de IA e testado manualmente pelo autor.*
