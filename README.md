# Enterprise Linux Lab no WSL 2 (RHEL 10.2, CentOS Stream 10, AL2023 & AL2027 Preview)

[![WSL 2](https://img.shields.io/badge/WSL-2-0078D6?logo=windows&logoColor=white)](https://learn.microsoft.com/windows/wsl/)
[![RHEL 10](https://img.shields.io/badge/RHEL-10.2-EE0000?logo=redhat&logoColor=white)](https://developers.redhat.com/products/rhel/download)
[![CentOS Stream 10](https://img.shields.io/badge/CentOS%20Stream-10-262577?logo=centos&logoColor=white)](https://www.centos.org/centos-stream/)
[![Amazon Linux 2023](https://img.shields.io/badge/Amazon%20Linux-2023-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/linux/amazon-linux-2023/)
[![Amazon Linux 2027 Preview](https://img.shields.io/badge/Amazon%20Linux-2027%20Preview-FF9900?logo=amazon-aws&logoColor=white)](https://amazonlinux.com/)
[![Shell Script](https://img.shields.io/badge/Bash-Audit-4EAA25?logo=gnu-bash&logoColor=white)](#)

Guia prático e **CLI-First** criado para ensinar **profissionais de TI e estudantes** a montar um laboratório local no **Windows Subsystem for Linux (WSL 2)** utilizando distribuições **Enterprise Linux que não são distribuídas pela Microsoft no catálogo padrão do WSL (`wsl --list --online`)** — cobrindo desde a imagem oficial `.wsl` com **Red Hat Developer Subscription** (**RHEL 10.2**) até a extração de imagens OCI via Docker/Podman (**CentOS Stream 10**, **Amazon Linux 2023** e **AL2027 Preview**), com instalação mínima de pacotes e script único de checagem final.

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
| systemd + SSHD + Base |     check-wsl-el.sh        |     (ext4.vhdx)       |
+-----------------------+                            +-----------------------+
```

1. **Extração OCI (`Docker`/`Podman` -> `rootfs.tar`):** Utiliza uma instância auxiliar do WSL 2 com Docker (ou Podman) para baixar a imagem oficial limpa e exportar o sistema de arquivos.
2. **Registro Nativo (`wsl --import`):** Cria o disco virtual `ext4.vhdx` dedicado no host Windows 11.
3. **Configuração Interna Manual:** Como imagens OCI mínimas sobem sem `/etc/fstab`, `systemd`, usuário comum ou `sshd` (e sem `/mnt/c` montado até corrigir o `fstab`), a configuração mínima é executada passo a passo dentro de `wsl -d <distro> -u root`.
4. **Checagem Final (`scripts/check-wsl-el.sh`):** Script único de auditoria (somente leitura) para validar `os-release`, `/etc/fstab`, `/mnt/c`, `systemd` como PID 1, usuário no grupo `wheel`, `sudo`, `/etc/wsl.conf` e `sshd`.

---

## Estrutura do Repositório

```text
wsl2-enterprise-linux-lab/
├── README.md                        # Visão geral, ecossistema, .wslconfig e guia rápido
├── assets/imgs/rhel-10/             # 12 capturas reais do guia RHEL 10.2
├── docs/
│   ├── rhel-10.md                   # Guia completo RHEL 10.2 (.wsl + Subscription Manager)
│   ├── centos-stream-10.md          # Passo a passo completo e instalação mínima (CentOS Stream 10)
│   ├── amazon-linux-2023.md         # Passo a passo completo, /etc/fstab e AWS CLI v2 (AL2023)
│   └── amazon-linux-2027-preview.md # Passo a passo completo do AL2027 Preview (.docker.tar.xz / ECR)
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

## Quando Usar o Docker para Gerar a Imagem WSL

A escolha de usar ou não o Docker depende exclusivamente de como cada distribuição é disponibilizada pelo fabricante. Quando há uma imagem oficial `.wsl` pronta para importação — como no caso do Red Hat Enterprise Linux 10.2 via Red Hat Developer Subscription — o Docker é desnecessário: basta baixar o pacote nativo e registrar diretamente com `wsl --import`. Por outro lado, distribuições que são oferecidas apenas como imagens OCI/container (CentOS Stream 10, Amazon Linux 2023 e Amazon Linux 2027 Preview) precisam do Docker apenas como ferramenta de extração, rodando em uma instância WSL auxiliar: a imagem é baixada, exportada como `rootfs.tar`, importada para o WSL 2 e o arquivo tar é imediatamente removido. Dessa forma, o Docker nunca permanece na instância final e serve somente para gerar o filesystem que será importado.

| Distribuição | Forma de distribuição no WSL 2 | Usa Docker? | Origem |
| :--- | :--- | :---: | :--- |
| **Red Hat Enterprise Linux 10.2** | Imagem oficial `.wsl` + Red Hat Developer Subscription | Não | developers.redhat.com/rhel |
| **CentOS Stream 10** | Extração OCI (`quay.io`) → `rootfs.tar` | Sim | `quay.io/centos/centos:stream10` |
| **Amazon Linux 2023** | Extração OCI (`public.ecr.aws`) → `rootfs.tar` | Sim | `public.ecr.aws/amazonlinux/amazonlinux:2023` |
| **Amazon Linux 2027 Preview** | `.docker.tar.xz` via CDN AWS → `rootfs.tar` | Sim | `cdn-al2027.amazonlinux.com` |

---

## Pré-requisitos

* **Windows 11** (ou Windows 10 2004+) com **WSL 2** habilitado (`wsl --update` atualizado).
* Uma distribuição WSL auxiliar com **Docker Engine** (ou **Podman**) ativo (ex: `Ubuntu-26.04`), utilizada apenas durante a extração do `rootfs.tar`.
* Repositório clonado em `C:\WSL\wsl2-enterprise-linux-lab` (ou ajuste o caminho ao executar `scripts/check-wsl-el.sh`).
* **Hardware para RHEL 10 / CentOS Stream 10:** processador compatível com **`x86-64-v3`** (suporte a instruções AVX/AVX2).

---

## Configuração Global Recomendada (`.wslconfig`)

Para ambientes de laboratório em notebooks/estações corporativas (VPNs, proxies e múltiplos serviços locais), recomenda-se criar ou ajustar o arquivo `%UserProfile%\.wslconfig` no Windows:

```ini
[wsl2]
memory=8GB
processors=4
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
```

> **Dica:** Após alterar o `.wslconfig`, aplique as mudanças com `wsl --shutdown` no PowerShell. O modo `mirrored` evita conflitos de rede com VPNs e compartilha o `localhost` entre Windows e WSL 2.

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

**Amazon Linux 2027 (Preview):**
```bash
mkdir -p /mnt/c/WSL/amazonlinux-2027/disk
curl -fsSLO https://cdn-al2027.amazonlinux.com/os-images/2027.0.20261109.0/container/al2027-preview-container-2027.0.20261109.0-x86_64.docker.tar.xz
LOADED_IMAGE=$(docker load -i al2027-preview-container-2027.0.20261109.0-x86_64.docker.tar.xz | awk '/Loaded image/{print $NF}')
docker create --name temp-al2027 "$LOADED_IMAGE"
docker export temp-al2027 -o /mnt/c/WSL/amazonlinux-2027/rootfs.tar
docker rm temp-al2027
```

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

## Licença

Este projeto está licenciado sob a licença [MIT](LICENSE).

---

## Autor

**Alex Luiz Rabelo** — Especialista em Infraestrutura de TI, Middleware, DevOps & SRE
* GitHub: [github.com/AlexRabelo](https://github.com/AlexRabelo)
* Portfólio: [alexrabelo.github.io](https://alexrabelo.github.io/)
* LinkedIn: [linkedin.com/in/alexrabelo](https://www.linkedin.com/in/alexrabelo/)

---

*Transparência de IA: Este projeto foi estruturado e revisado com auxílio de ferramentas de IA e testado manualmente pelo autor.*
