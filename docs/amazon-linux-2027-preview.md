# Validação do Amazon Linux 2027 (Preview) no WSL 2

Guia prático e manual para provisionar e validar o **Amazon Linux 2027 (AL2027 Preview)** no **WSL 2** a partir do arquivo oficial `.docker.tar.xz` publicado no CDN da AWS (`cdn-al2027.amazonlinux.com`).

> **Por que manual?** Logo após `wsl --import`, imagens OCI mínimas do Amazon Linux ainda não possuem `/etc/fstab`, `systemd`, usuário comum ou `sshd` — por isso o próprio `/mnt/c` pode não estar montado no primeiro boot. O passo a passo abaixo resolve tudo linha a linha dentro da instância e usa `scripts/check-wsl-el.sh` para a checagem final.

---

## 1. Contexto Técnico

O **Amazon Linux 2027 (AL2027)** é a próxima geração da família Amazon Linux mantida pela AWS (também derivada do ecossistema **Fedora** / RPM), em **Public Preview** desde setembro de 2026 para validação antecipada antes do lançamento geral (GA). Entre as novidades arquiteturais desta geração estão o **`dnf5`** como gerenciador de pacotes padrão, **OpenSSL 3.5 + AWS-LC** e **SELinux em modo `enforcing` por padrão** em instâncias EC2 (no WSL 2, o user space roda sobre o kernel mantido pela Microsoft).

- **Documentação e fontes oficiais:** [amazonlinux.com](https://amazonlinux.com/) · [CDN AL2027 Preview](https://cdn-al2027.amazonlinux.com/) · [ECR Public `amazonlinux:2027`](https://gallery.ecr.aws/amazonlinux/amazonlinux) · [Microsoft WSL Custom Distro](https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro)

---

## 2. Passo a Passo Manual

### Etapa 1: Baixar e converter `.docker.tar.xz` para `rootfs.tar` (Ubuntu WSL 2)

> **Atenção:** o arquivo `.docker.tar.xz` é um pacote de camadas Docker (`manifest.json` + blobs), **não** um `rootfs.tar` direto. Por isso é necessário fazer `docker load` seguido de `docker export`. Como alternativa, você também pode extrair diretamente da tag sempre atualizada no ECR Public (`public.ecr.aws/amazonlinux/amazonlinux:2027`), evitando URLs com timestamp de build.

```bash
mkdir -p /mnt/c/WSL/amazonlinux-2027/disk

curl -fsSLO https://cdn-al2027.amazonlinux.com/os-images/2027.0.20261109.0/container/al2027-preview-container-2027.0.20261109.0-x86_64.docker.tar.xz
curl -fsSLO https://cdn-al2027.amazonlinux.com/os-images/2027.0.20261109.0/container/SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing

LOADED_IMAGE=$(docker load -i al2027-preview-container-2027.0.20261109.0-x86_64.docker.tar.xz | awk '/Loaded image/{print $NF}')
docker create --name temp-al2027 "$LOADED_IMAGE"
docker export temp-al2027 -o /mnt/c/WSL/amazonlinux-2027/rootfs.tar
docker rm temp-al2027
rm -f al2027-preview-container-2027.0.20261109.0-x86_64.docker.tar.xz SHA256SUMS
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

# 2. Atualiza pacotes e instala base mínima WSL 2 + systemd + langpacks (evita erros de locale)
dnf update -y
dnf install -y --allowerasing \
  systemd sudo passwd shadow-utils \
  glibc-langpack-en glibc-langpack-pt \
  bash-completion vim-enhanced curl which less \
  procps-ng iproute iputils openssh-server openssh-clients \
  tar gzip unzip

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

> **Nota sobre autenticação SSH (Senha vs. Chave):** Como este é um laboratório estritamente local (`127.0.0.1`), `PasswordAuthentication yes` está habilitado para facilitar os primeiros testes. Porém, o ideal em ambientes reais — e prática recomendada desde já — é utilizar **autenticação por chave SSH** (`ssh-keygen` + `authorized_keys`), tema que será abordado futuramente neste projeto. Consulte a documentação oficial do OpenSSH: [OpenSSH Manual](https://www.openssh.com/manual.html) · [`ssh-keygen(1)`](https://man.openbsd.org/ssh-keygen.1) · [`sshd(8)` — `authorized_keys`](https://man.openbsd.org/sshd.8#AUTHORIZED_FILES).

### Etapa 4: Reiniciar para ativar `systemd` e `/mnt/c` (PowerShell)

```powershell
wsl --terminate amazonlinux-2027
wsl -d amazonlinux-2027
```

---

## 3. Troubleshooting Validado na Prática

* **Erros de locale (`setlocale: LC_ALL: cannot change locale`) na inicialização:** imagens OCI mínimas trazem apenas `C.UTF-8` e omitem pacotes de idioma, gerando avisos quando o WSL/SSH herda `en_US.UTF-8` ou `pt_BR.UTF-8`. A solução validada no AL2027 Preview é instalar:
  ```bash
  sudo dnf install -y glibc-langpack-en glibc-langpack-pt
  ```

---

## 4. Checagem Final de Auditoria

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
