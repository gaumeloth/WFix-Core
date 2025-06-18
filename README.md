[![Logo](WFix-core_logo.png)](https://github.com/gaumeloth/WFix-Core)

# 🛠️ WFix-Core

**Uno script PowerShell interattivo per la diagnostica e la riparazione automatica di Windows**, progettato per essere semplice, sicuro e dettagliato nei log.

**`WFix-Core`** è uno script PowerShell interattivo che fornisce un toolkit essenziale per diagnosticare, riparare e ottimizzare i componenti fondamentali del sistema operativo Windows.
Dal kernel NTFS al Component Store, dalla rete Winsock ai file di sistema, WFix-Core esegue interventi critici con log dettagliati e controllo completo da terminale.
Progettato per essere sicuro, modulare e leggibile, è pensato sia per utenti avanzati che per professionisti IT.

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)](https://learn.microsoft.com/en-us/powershell/)
[![Windows](https://img.shields.io/badge/Platform-Windows-blue?logo=windows)](https://www.microsoft.com/windows)
[![Licenza](https://img.shields.io/github/license/gaumeloth/WFix-Core)](https://github.com/gaumeloth/WFix-Core/blob/main/LICENSE)
---

## 📋 Funzionalità

✅ Interfaccia interattiva da terminale  
✅ CHKDSK (riparazione disco)  
✅ DISM (riparazione immagine Windows)  
✅ SFC (riparazione file di sistema)  
✅ NETSH (ripristino rete)  
✅ verifica ed aggiornamento driver (pnputil/WindowsUpdate)
✅ Esportazione EventLog (System, Application, DISM, WindowsUpdate)  
✅ Logging completo per debugging o analisi post-mortem

---

## 📂 Struttura dei Log

Alla fine della scansione troverai una directory `WFixLogs` sul Desktop contenente:

```
WFixLogs/
├── repair-YYYYMMDD-HHMMSS.log      # Log principale dello script
├── chkdsk.log                      # Log dedicato a CHKDSK
└── EventLogs/
    ├── System.xml
    ├── Application.xml
    ├── DISM.xml
    └── WindowsUpdate.xml
```

---

## ⚙️ Requisiti

- PowerShell 5.1 o superiore (incluso in Windows 10/11)
- Privilegi di amministratore
- Sistema operativo: **Windows 10, 11, Server 2016+**
- (Opzionale) Connettività Internet e modulo `PSWindowsUpdate` per installare i driver

---

## 🚀 Come usare

### Metodo rapido:

1. Scarica o clona il repository:

```bash
git clone https://github.com/gaumeloth/WFix-Core.git
cd WFix-Core
```

2. Esegui PowerShell come **amministratore**

3. Avvia lo script:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\WFix-Core.ps1
```

4. Segui le istruzioni sullo schermo  
5. Al termine, scegli se aprire la cartella dei log

---

## 🔒 Sicurezza

- Lo script **non invia dati online**  
- Nessuna modifica distruttiva o cancellazione file  
- Tutte le azioni sono tracciate in chiaro nei log  
- Eventuali riavvii richiesti sono indicati esplicitamente

---

## 🛑 Avvertenze

- CHKDSK potrebbe programmare il controllo al successivo riavvio
- In ambienti aziendali, valuta la policy di esecuzione script (`ExecutionPolicy`)
- Se usi software di terze parti per backup/disco/antivirus, controlla che non interferiscano

---

## 📄 Licenza

Distribuito sotto licenza MIT. Vedi `LICENSE` per dettagli.

---

## 🙋‍♀️ Autore

Creato da **Gaumeloth** per uso tecnico e di assistenza sistemistica.

Per suggerimenti, fork, migliorie o bug: [Apri una Issue](https://github.com/gaumeloth/WFix-Core/issues)
