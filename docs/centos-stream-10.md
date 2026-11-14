# Implantação e Auditoria do CentOS Stream 10 no WSL 2

Guia técnico detalhado para provisionar o **CentOS Stream 10 ("Coughlan")** no **Windows Subsystem for Linux (WSL 2)** a partir de sua imagem oficial OCI (`quay.io/centos/centos:stream10`), incluindo configuração de `systemd`, **OpenSSH Server**, criação de usuário administrativo e adequação ao perfil *Minimal Install* / certificação **LPIC-1**.

---

## 1. Contexto Técnico

Na árvore do ecossistema Red Hat, o **CentOS Stream 10 ("Coughlan")** ocupa a posição **midstream** entre o **Fedora** (*upstream*, onde as inovações surgem) e o **Red Hat Enterprise Linux 10** (*downstream*, versão corporativa estável). Tudo o que entra no CentOS Stream 10 compõe o próximo *minor release* do RHEL 10 (Kernel 6.12, arquitetura base `x86-64-v3`).

Como não há pacote oficial da distribuição no catálogo online da Microsoft Store (`wsl --list --online`), a implantação mais limpa e auditável consiste em extrair o sistema de arquivos (`rootfs.tar`) da imagem oficial mantida pela Red Hat/CentOS no Quay.io e importá-lo como disco virtual dedicado (`ext4.vhdx`) no WSL 2.

- **Documentação oficial:** [centos.org/centos-stream](https://www.centos.org/centos-stream/) · [docs.centos.org](https://docs.centos.org/) 

---

## 2. Passo a Passo Manual

### Etapa 1: Extração do `rootfs.tar` via Docker (Ubuntu WSL 2)

```bash
mkdir -p /mnt/c/WSL/centos-stream10/disk

docker pull quay.io/centos/centos:stream10
docker create --name temp-centos10 quay.io/centos/centos:stream10
docker export temp-centos10 -o /mnt/c/WSL/centos-stream10/rootfs.tar
docker rm temp-centos10
```

### Etapa 2: Registro da Instância no WSL 2 (PowerShell)

```powershell
wsl --import centos-stream10 C:\WSL\centos-stream10\disk C:\WSL\centos-stream10\rootfs.tar --version 2
Remove-Item C:\WSL\centos-stream10\rootfs.tar
```

### Etapa 3: Provisionamento de Pacotes, Usuário e OpenSSH Server

Acesse a instância como `root`:

```powershell
wsl -d centos-stream10 -u root
```

Instale manualmente os grupos essenciais dentro da instância:

```bash
dnf update -y
dnf install -y \
  systemd sudo passwd shadow-utils bash-completion vim-enhanced curl which less \
  procps-ng iproute iputils bind-utils net-tools openssh-server openssh-clients \
  man-db man-pages info file tree zip unzip bzip2 xz patch rsync lsof time hostname \
  wget tcpdump traceroute nmap-ncat chrony cronie at rsyslog logrotate \
  e2fsprogs xfsprogs dosfstools parted lvm2 acl policycoreutils policycoreutils-python-utils

# Criação do usuário com privilégios sudo (wheel)
useradd -m -G wheel -s /bin/bash labuser
passwd labuser

# Geração das chaves de host do OpenSSH e configuração na porta 2222
ssh-keygen -A
mkdir -p /etc/ssh/sshd_config.d /run/sshd
cat <<EOF > /etc/ssh/sshd_config.d/99-wsl-remote.conf
Port 2222
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
hostname=centos-stream10
generateHosts=true

[user]
default=labuser
EOF
exit
```

No **PowerShell**, encerre e reinicie a instância para carregar o `systemd` como PID 1:

```powershell
wsl --terminate centos-stream10
wsl -d centos-stream10
```

---

## 3. Lições Aprendidas & Troubleshooting de Imagens OCI

Durante a validação deste laboratório, foram diagnosticados três comportamentos específicos de imagens mínimas de contêiner (`quay.io/centos/centos:stream10`):

1. **`-bash: systemctl: command not found` mesmo com `systemd=true`:**
   * **Causa:** Imagens OCI não incluem o pacote `systemd` por padrão, pois contêineres executam processos diretamente sem *init system*. Sem `/sbin/init`, o WSL não consegue promover o `systemd` a PID 1.
   * **Solução:** Instalar explicitamente `dnf install -y systemd` e executar `wsl --terminate <distro>`.
2. **`-bash: ps: command not found` ao auditar processos:**
   * **Causa:** O pacote `procps-ng` (`ps`, `top`, `free`, `uptime`, `pgrep`) é omitido para reduzir o tamanho da imagem base (~200 MB).
   * **Solução:** Utilizar `cat /proc/1/comm` para checagem imediata e instalar `procps-ng` junto com `iproute` e `bind-utils`.
3. **Falha ao iniciar `sshd` (`No host keys available`):**
   * **Causa:** Imagens base de contêiner não possuem chaves criptográficas de servidor em `/etc/ssh/ssh_host_*_key`.
   * **Solução:** Executar `ssh-keygen -A` antes de habilitar o serviço `sshd`.

---

## 4. Checagem Final de Auditoria

Após reiniciar (`wsl --terminate centos-stream10`), execute o script de auditoria ou valide manualmente:

```bash
bash /mnt/c/WSL/wsl2-enterprise-linux-lab/scripts/check-wsl-el.sh labuser 2222

whoami && pwd                       # labuser | /home/labuser
ps -p 1 -o pid,comm                 # 1 systemd
systemctl is-active sshd            # active
ssh -p 2222 labuser@localhost "hostname && uptime"
sudo dnf repolist                   # baseos, appstream, extras-common
```

---

*Transparência de IA: Este projeto foi estruturado e revisado com auxílio de ferramentas de IA e testado manualmente pelo autor.*
