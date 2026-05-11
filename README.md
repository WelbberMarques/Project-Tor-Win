# TorProxy-Win

> Roteia todo o tráfego do Windows pela rede Tor — sem WSL, sem VPN paga.

```
  ████████╗ ██████╗ ██████╗     ██╗    ██╗██╗███╗  ██╗
     ██╔══╝██╔═══██╗██╔══██╗    ██║    ██║██║████╗ ██║
     ██║   ██║   ██║██████╔╝    ██║ █╗ ██║██║██╔██╗██║
     ██║   ██║   ██║██╔══██╗    ██║███╗██║██║██║╚████║
     ██║   ╚██████╔╝██║  ██║    ╚███╔███╔╝██║██║ ╚███║
     ╚═╝    ╚═════╝ ╚═╝  ╚═╝     ╚══╝╚══╝ ╚═╝╚═╝  ╚══╝
```

![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue?logo=windows)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-2.0-orange)
![Author](https://img.shields.io/badge/author-Welbber%20Marques-yellow)

---

## O que é

Script PowerShell equivalente ao `proxychains` do Linux. Todo o tráfego do Windows — browsers, apps, sistema — é roteado pelo Tor automaticamente via `tun2socks`. Na primeira execução baixa e instala tudo sozinho.

**Componentes instalados automaticamente:**
- Tor Expert Bundle (versão mais recente)
- Tor Browser (versão mais recente)
- tun2socks
- WinTun driver

---

## Requisitos

| Item | Mínimo |
|------|--------|
| Sistema | Windows 10 / 11 |
| Shell | PowerShell 5.1+ |
| Permissão | Administrador |
| Rede | Acesso à internet |

---

## Instalação

**1. Clone o repositório**

```powershell
git clone https://github.com/WelbberMarques/TorProxy-Win.git
```

**2. Abrir PowerShell como Administrador na pasta do projeto**

Navegue até a pasta `TorProxy-Win` → clique com botão direito → **"Abrir no Terminal"**

Ou via `Win + X` → Terminal (Administrador) e navegue:

```powershell
cd "TorProxy-Win"
```

**3. Liberar execução de scripts (uma vez)**

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
```

**4. Instalar componentes**

```powershell
.\TorProxy-Win.ps1 -Action install
```

**5. Rodar**

```powershell
.\TorProxy-Win.ps1 -Action start
```

Na primeira execução instala tudo automaticamente. Da segunda em diante vai direto.

Quando ativo, todo o tráfego do PC passa pelo Tor e o Tor Browser abre automaticamente. Para parar pressione **Ctrl+C** — a rede é restaurada automaticamente.

---

## Comandos

| Comando | Descrição |
|---------|-----------|
| `-Action install` | Baixa e instala todos os componentes (Tor, tun2socks, WinTun, Tor Browser) |
| `-Action start` | Inicia — instala se necessário, roteia tudo pelo Tor e abre o Tor Browser |
| `-Action start -ExitCountry CH` | Inicia com nó de saída em país específico |
| `-Action findgoogle` | Troca circuito automaticamente até o Google funcionar |
| `-Action status` | Exibe estado atual |
| `-Action uninstall` | Remove tudo do sistema |

Para parar: **Ctrl+C**

---

## ExitCountry

Força o IP de saída a ser de um país específico.

```powershell
.\TorProxy-Win.ps1 -Action start -ExitCountry CH   # Suíça
.\TorProxy-Win.ps1 -Action start -ExitCountry US   # EUA
.\TorProxy-Win.ps1 -Action start -ExitCountry JP   # Japão
.\TorProxy-Win.ps1 -Action start -ExitCountry DE   # Alemanha
.\TorProxy-Win.ps1 -Action start -ExitCountry NL   # Holanda
```

Use o código ISO do país (2 letras). Sem o parâmetro o Tor escolhe automaticamente.

---

## Como funciona

```
[Qualquer app / browser]
          |
  [TUN Virtual Adapter]   <- WinTun
          |
    [tun2socks.exe]        <- captura todo TCP/UDP
          | SOCKS5
     [tor.exe :9050]
          |
  [Rede Tor - 3 relés]
          |
  [IP de saída anônimo]
```

- Todo o tráfego TCP/UDP passa pelo adaptador TUN
- DNS também roteia pelo Tor — sem DNS leak
- Nenhum app precisa ser configurado manualmente

---

## Verificar

Abra `https://check.torproject.org` no browser após iniciar.

Ou via terminal:

```powershell
# IP atual via Tor
curl --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip

# IP público (deve ser do Tor)
curl https://ifconfig.me
```

---

## Estrutura

```
TorProxy-Win/
├── TorProxy-Win.ps1   # Script principal
├── README.md
└── LICENSE
```

Os binários (Tor, tun2socks, WinTun) são baixados em `C:\ProgramData\TorProxy\` na primeira execução.

---

## Aviso legal

Projeto open-source para fins de **privacidade, pesquisa e educação**.  
O uso para atividades ilegais é de responsabilidade exclusiva do usuário.  
Este projeto não possui afiliação com o Tor Project.

---

## Contribuindo

Pull requests são bem-vindos. Para mudanças maiores, abra uma issue primeiro para discutir o que você gostaria de alterar.

1. Fork o projeto
2. Crie sua branch (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Add MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

---

## Autor

**Welbber Marques**

- GitHub: [@WelbberMarques](https://github.com/WelbberMarques)
- Email: Welbbermarques14@gmail.com

---

## Licença

MIT © 2025 [Welbber Marques](https://github.com/WelbberMarques)

Veja o arquivo [LICENSE](LICENSE) para detalhes.
