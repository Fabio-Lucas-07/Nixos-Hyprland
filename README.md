# Nixos-Hyprland

Configuração NixOS com Hyprland e o tema 43PR, pronta para ser instalada em outros PCs.

## Instalar em outro PC

Requisitos: NixOS já instalado, UEFI e x86_64.

```sh
nix-shell -p git gh --run 'gh auth login && gh repo clone Fabio-Lucas-07/Nixos-Niri ~/nixos-config && ~/nixos-config/install.sh'
```

O script pergunta o nome do PC, detecta o hardware, gera `hosts/<nome>/` e move o repositório para `/etc/nixos`. Se o usuário `fabio` ainda não tiver senha, ele pede uma. Depois, é só reiniciar: o wallpaper e as cores são gerados no primeiro login.

Outros PCs iniciam sem Secure Boot. Para ativar em um deles, crie as chaves do Lanzaboote e use `machine.secureBoot = true` em `hosts/<nome>/default.nix`.

## Estrutura

| Caminho | Conteúdo |
| --- | --- |
| `configuration.nix`, `home.nix` | Configuração comum a todos os PCs |
| `hosts/<nome>/` | Hardware e opções de cada PC; cada pasta vira uma configuração do flake |
| `modules/machine.nix` | Boot, GPU e energia conforme as opções de `hosts/<nome>/` |
| `scripts/` | Verificações do sistema |
| `config/dotfiles/43pr/` | Tema 43PR, adaptado para NixOS |
| `config/sessions/hyprland/` | Sessão do Hyprland |
| `config/programs/` | Outros programas, importados automaticamente |

## Aplicar mudanças

```sh
sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)
```

## Notebook

Em `hosts/alienware`, a tela roda na GPU Intel. Na bateria, a NVIDIA fica desligada até ser usada; na tomada, fica sempre ligada:

| Uso | Comando |
| --- | --- |
| Programa na NVIDIA | `Super + Alt + R` (menu de apps) ou `nv programa` no terminal |
| Jogo na Steam (opções de inicialização) | `gamemoderun nvidia-offload %command%` |
| Monitor na porta HDMI, ligada à NVIDIA | Conecte o cabo: funciona na hora, e a NVIDIA liga sozinha |
| Conferir o estado da energia | `scripts/power-check.sh` |
| Comparar antes e depois de suspender | `scripts/power-check.sh --resume` |

As portas USB-C ficam na GPU Intel. Sem cabo no HDMI e na bateria, a NVIDIA volta a desligar sozinha.

## Atalhos principais

| Atalho | Ação |
| --- | --- |
| `Super + W` ou `Super + T` | Terminal |
| `Super + R` | Lançador |
| `Super + B` | Navegador |
| `Super + E` | Arquivos |
| `Super + Q` | Fechar janela |
| `Super + S` | Ações rápidas |
| `Super + Shift + I` | Configurações |
| `Super + Shift + W` | Wallpapers |
| `Super + Shift + B` | Mostrar ou ocultar a barra |
| `Super + Shift + V` | Histórico da área de transferência |
| `Super + Shift + T` | Notas e lembretes |
| `Super + Shift + R` | Gravar a tela |
| `Super + Shift + S` | Capturar uma área da tela |
| `Super + Tab` | Bloquear a tela |
| `` Super + ` `` | Menu de energia |

A lista completa fica em `Super + Shift + I`, na página de atalhos.

## Créditos

O tema vem de [43PR/dotfiles](https://github.com/43PR/dotfiles), com licença MIT (`config/dotfiles/43pr/LICENSE`).
