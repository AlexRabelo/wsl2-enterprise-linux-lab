# Padrão Visual e Checklist de Capturas (`assets/imgs/`)

Guia de referência para manter todas as capturas de tela do repositório com **design uniforme** e **sem exposição de dados pessoais** do ambiente local.

---

## 1. Padrão Visual Único

* **Resolução e proporção:** `1200×675` px (16:9), formato `.png`.
* **Fundo do canvas:** cor sólida `#0D1117` (sem bordas ou resquícios de papel de parede nos cantos arredondados).
* **Capturas de Terminal (Windows Terminal):**
  * Tamanho fixo da janela: **105 colunas × 26 linhas** (ou ~`1080×600` px), centralizada no canvas (`~60 px` de margem lateral).
  * Fonte padronizada: `Cascadia Mono` ou `JetBrains Mono` (`14pt`).
* **Capturas de Navegador:**
  * Janela em **modo anônimo/convidado** (~`1100×620` px), zoom `100%`, sem barra de favoritos, extensões ou perfil pessoal visível.

---

## 2. Checklist de Higienização (Antes de Capturar)

### No Windows (PowerShell)
- [ ] Entrar em diretório neutro antes de rodar comandos:
  ```powershell
  Set-Location C:\WSL
  ```
- [ ] Evitar comandos que imprimam `C:\Users\<seu_usuario>` na saída (ex.: preferir `mkdir C:\WSL\RHEL10.2 | Out-Null` em vez de `mkdir $HOME\WSL`).
- [ ] Não exibir outras distribuições pessoais em `wsl --list --verbose` (ou filtrar/isolar o ambiente de gravação).

### Dentro da instância Linux (WSL 2)
- [ ] Configurar hostname neutro no `/etc/wsl.conf` **antes** de registrar ou capturar o prompt:
  ```ini
  [network]
  hostname=rhel-10
  ```
- [ ] Reiniciar a instância (`wsl --terminate RHEL-10.2`) para o novo hostname refletir na aba do terminal, no prompt e no `subscription-manager`.
- [ ] Navegar para `cd ~` antes de capturar (`[demo@rhel-10 ~]$`, evitando exibir caminhos montados de usuário do Windows).
- [ ] Mascarar ou omitir `Username` pessoal, `UUID` do sistema e `view_id` de URLs antes de salvar o PNG.

---

## 3. Lista de Recaptura — `assets/imgs/rhel-10/`

| Arquivo | O que ajustar na recaptura |
|---|---|
| `wsl-list-verbose.png` | Aumentar janela ao padrão (`1080px`), remover borda ciano e usar `C:\WSL>` |
| `wsl-import-command.png` | Atualizar para `rhel-10.2-x86_64-wsl2.wsl` e ocultar `C:\Users\vialo` |
| `wsl-list-after-import.png` | Aumentar janela ao padrão (`1080px`) e remover borda ciano |
| `wsl-rhel-prompt.png` | Hostname `rhel-10` e diretório `cd /` ou `cd ~` (sem `vialo` / `NoteSamSung`) |
| `cat-redhat-release.png` | Atualizar para RHEL `10.2`, hostname `rhel-10` e janela no tamanho padrão |
| `subscription-manager-register.png` | Hostname `rhel-10`, mascarar username/UUID e janela no tamanho padrão |
| `subscription-manager-status.png` | Modo anônimo/recorte limpo sem perfil pessoal e com hostname `rhel-10` |
| `dnf-repolist.png` | Hostname `rhel-10` e mascarar username/UUID |
| `dnf-update.png` | Hostname `rhel-10` |
| `final-wsl-terminal.png` | Hostname `rhel-10`, usuário `demo` em `~` (sem `vialo`) e janela no tamanho padrão |
