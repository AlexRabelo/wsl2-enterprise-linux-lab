# Enterprise Linux Lab no WSL 2 (RHEL 10.2, CentOS Stream 10, AL2023 & AL2027 Preview)

[![WSL 2](https://img.shields.io/badge/WSL-2-0078D6?logo=windows&logoColor=white)](https://learn.microsoft.com/windows/wsl/)
[![RHEL 10](https://img.shields.io/badge/RHEL-10.2-EE0000?logo=redhat&logoColor=white)](https://developers.redhat.com/products/rhel/download)
[![CentOS Stream 10](https://img.shields.io/badge/CentOS%20Stream-10-262577?logo=centos&logoColor=white)](https://www.centos.org/centos-stream/)
[![Amazon Linux 2023](https://img.shields.io/badge/Amazon%20Linux-2023-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/linux/amazon-linux-2023/)
[![Shell Script](https://img.shields.io/badge/Bash-Audit-4EAA25?logo=gnu-bash&logoColor=white)](#)

Procedimento **CLI-First** documentado passo a passo para provisionar distribuições **Enterprise Linux** dentro do **Windows Subsystem for Linux (WSL 2)** — cobrindo desde a imagem oficial `.wsl` com **Red Hat Developer Subscription** (**RHEL 10.2**) até a extração de imagens OCI via Docker (**CentOS Stream 10**, **Amazon Linux 2023** e **AL2027 Preview**), com script único de checagem final.

---

## Arquitetura do Fluxo

```text
+-----------------------+       docker export        +-----------------------+
|   Registry Oficial    | -------------------------> |      rootfs.tar       |
| (Quay.io / ECR / CDN) |    (via Ubuntu WSL 2)      | (Sistema de Arquivos) |
+-----------------------+                            +-----------+-----------+
                                                                 |
                                                                 | wsl --import
                                                                 v
+-----------------------+   Configuração Manual +    +-----------------------+
|  Instância Operacional| <------------------------- |   Disco Virtual WSL   |
| systemd + SSHD + LPIC |     check-wsl-el.sh        |     (ext4.vhdx)       |
+-----------------------+                            +-----------------------+
```

1. **Extração OCI (`Docker` -> `rootfs.tar`):** Utiliza uma instância auxiliar do WSL 2 com Docker para baixar a imagem oficial limpa e exportar o sistema de arquivos.
2. **Registro Nativo (`wsl --import`):** Cria o disco virtual `ext4.vhdx` dedicado no host Windows 11.
3. **Configuração Interna Manual:** Como imagens OCI mínimas sobem sem `/etc/fstab`, `systemd`, usuário comum ou `sshd` (e sem `/mnt/c` montado até corrigir o `fstab`), a configuração é executada linha a linha dentro de `wsl -d <distro> -u root`.
4. **Checagem Final (`scripts/check-wsl-el.sh`):** Script único de auditoria (somente leitura) para validar `os-release`, `/etc/fstab`, `/mnt/c`, `systemd` como PID 1, grupo `wheel`, `/etc/wsl.conf` e `sshd`.

---

## Estrutura do Repositório

```text
wsl2-enterprise-linux-lab/
├── README.md                        # Visão geral, ecossistema, LPIC-1 e guia rápido
├── assets/imgs/rhel-10/             # 12 capturas reais do guia RHEL 10.2
├── docs/
│   ├── rhel-10.md                   # Guia completo RHEL 10.2 (.wsl + Subscription Manager)
│   ├── centos-stream-10.md          # Passo a passo completo e matriz LPIC-1 (CentOS Stream 10)
│   ├── amazon-linux-2023.md         # Passo a passo completo, /etc/fstab e AWS CLI v2 (AL2023)
│   └── amazon-linux-2027-preview.md # Passo a passo completo do AL2027 Preview (.docker.tar.xz)
└── scripts/
    └── check-wsl-el.sh              # Script único de checagem final da instância WSL 2
```

---

## Conceito e Ecossistema das Distribuições

Entender onde cada distribuição se posiciona na árvore Enterprise Linux ajuda a escolher o ambiente certo para estudo ou produção:

```text
Fedora (Upstream — inovação rápida)
   ├──▶ CentOS Stream 10 (Midstream — desenvolvimento contínuo do próximo RHEL 10.x)
   │       └──▶ Red Hat Enterprise Linux (Downstream — estável corporativo)
   └──▶ Amazon Linux 2023 / 2027 (Derivado Fedora — otimizado para AWS / EC2)
```

| Distribuição | Papel no Ecossistema | Origem no WSL 2 | Documentação Oficial |
| :--- | :--- | :--- | :--- |
| **Red Hat Enterprise Linux 10.2** | *Downstream* corporativo estável (derivado do CentOS Stream) | Imagem oficial `.wsl` + *Red Hat Developer Subscription* | [developers.redhat.com/rhel](https://developers.redhat.com/products/rhel/download) · [Guia RHEL on WSL](https://developers.redhat.com/articles/2025/05/20/getting-started-rhel-windows-subsystem-linux) |
| **CentOS Stream 10** | *Midstream* entre o **Fedora** e o **RHEL 10** | Extração OCI (`quay.io`) → `rootfs.tar` | [centos.org/centos-stream](https://www.centos.org/centos-stream/) · [docs.centos.org](https://docs.centos.org/) |
| **Amazon Linux 2023** | Base **Fedora** otimizada pela **AWS** (LTS até jun/2029) | Extração OCI (`public.ecr.aws`) → `rootfs.tar` | [docs.aws.amazon.com/linux/al2023](https://docs.aws.amazon.com/linux/al2023/ug/what-is-amazon-linux.html) |
| **Amazon Linux 2027 (Preview)** | Próxima geração **AWS Linux** em ciclo *Preview* | `.docker.tar.xz` (`cdn-al2027.amazonlinux.com`) → `rootfs.tar` | [cdn-al2027.amazonlinux.com](https://cdn-al2027.amazonlinux.com/) · [amazonlinux.com](https://amazonlinux.com/) |

---

## Pré-requisitos

* **Windows 11** com **WSL 2** habilitado (`wsl --update` atualizado).
* Uma distribuição WSL auxiliar com **Docker Engine** ativo (ex: `Ubuntu-26.04`), utilizada apenas durante a extração do `rootfs.tar`.

---

## Resumo do Fluxo Manual

### Etapa 1 — Extrair o `rootfs.tar` no WSL Ubuntu (com Docker)

**CentOS Stream 10:**
```bash
mkdir -p /mnt/c/WSL/centos-stream10/disk
docker pull quay.io/centos/centos:stream10
docker create --name temp-centos10 quay.io/centos/centos:stream10
docker export temp-centos10 -o /mnt/c/WSL/centos-stream10/rootfs.tar
docker rm temp-centos10
```

**Amazon Linux 2023:**
```bash
mkdir -p /mnt/c/WSL/amazonlinux-2023/disk
docker pull public.ecr.aws/amazonlinux/amazonlinux:2023
docker create --name temp-al2023 public.ecr.aws/amazonlinux/amazonlinux:2023
docker export temp-al2023 -o /mnt/c/WSL/amazonlinux-2023/rootfs.tar
docker rm temp-al2023
```

**Amazon Linux 2027 (Preview):** siga o guia [docs/amazon-linux-2027-preview.md](docs/amazon-linux-2027-preview.md) (usa `docker load` no `.docker.tar.xz`).

### Etapa 2 — Importar no WSL 2 (PowerShell)

```powershell
wsl --import amazonlinux-2023 C:\WSL\amazonlinux-2023\disk C:\WSL\amazonlinux-2023\rootfs.tar --version 2
Remove-Item C:\WSL\amazonlinux-2023\rootfs.tar
```

### Etapa 3 — Configurar dentro da instância (`wsl -d <distro> -u root`)

Siga os comandos linha a linha do guia da sua distribuição em `docs/`:
- [Red Hat Enterprise Linux 10.2](docs/rhel-10.md) *(usa imagem oficial `.wsl`, sem etapa Docker)*
- [CentOS Stream 10](docs/centos-stream-10.md)
- [Amazon Linux 2023](docs/amazon-linux-2023.md)
- [Amazon Linux 2027 (Preview)](docs/amazon-linux-2027-preview.md)

### Etapa 4 — Reiniciar e rodar a checagem final

No **PowerShell**:
```powershell
wsl --terminate amazonlinux-2023
wsl -d amazonlinux-2023
```

Dentro da instância (já com `/mnt/c` montado):
```bash
bash /mnt/c/WSL/wsl2-enterprise-linux-lab/scripts/check-wsl-el.sh labuser 2223
```

---

## Escopo de Estudo LPIC-1: WSL 2 vs. VM Completa (VirtualBox/VMware)

| Domínio LPIC-1 | Ambiente Recomendado | Justificativa Técnica |
| :--- | :--- | :--- |
| **103** (GNU/Unix, Pipes, Regex, `sed`, `awk`), **102.5** (`rpm`/`dnf`), **104.5** (Permissões/ACLs), **107** (Usuários, `cron`, `at`), **109/110** (Rede & SSH) | **WSL 2 (Este Laboratório)** | Baixo consumo de RAM, inicialização instantânea e fidelidade total do *user-space* Enterprise Linux (CentOS 10, AL2023, AL2027). |
| **101** (Hardware/Módulos Kernel), **102.1/102.2** (Particionamento real & GRUB2), **104.1-104.4** (`mkfs`, `fsck`, `mount`, LVM físico) e **SELinux Enforcing** | **Hypervisor Tipo 2 ([VirtualBox](https://github.com/AlexRabelo/lab-al2023-virtualbox) / VMware)** | O WSL 2 utiliza um kernel Linux mantido pela Microsoft sem dispositivos de bloco físicos expostos ao GRUB2 e sem SELinux ativo no kernel. |

---

## Autor

**Alex Luiz Rabelo** — Especialista em Infraestrutura de TI, Middleware, DevOps & SRE
* GitHub: [github.com/AlexRabelo](https://github.com/AlexRabelo)
* Portfólio: [alexrabelo.github.io](https://alexrabelo.github.io/)
* LinkedIn: [linkedin.com/in/alexrabelo](https://www.linkedin.com/in/alexrabelo/)

---

*Transparência de IA: Este projeto foi estruturado e revisado com auxílio de ferramentas de IA e testado manualmente pelo autor.*
