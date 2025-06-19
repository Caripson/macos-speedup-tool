
# macOS SpeedUp Tool 🚀

> **Trimma din äldre Mac på fem minuter.**  
> Inga konstigheter – ett enda script stänger av bakgrundstjänster, sparar CPU & batteri och kan när som helst ångras.

---

## 📝 Vad är det här?

Ett litet **bash-script (`speedup.sh`)** som:

| ✅ Funktion                 | Beskrivning                                                        |
|-----------------------------|--------------------------------------------------------------------|
| **Interaktiv meny**         | Svar *y* / *n* för varje del du vill stänga av                     |
| **Auto-läge**               | `--auto all` (eller lista) → allt fixas utan frågor                |
| **Verifiera**               | `--verify` visar tydligt ✅ / ❌ för varje modul                    |
| **Undo**                    | `--undo <modul>` återställer en enda sak, t.ex. `--undo siri`      |
| **Säkert**                  | Kräver sudo – men ändrar **inget** permanent i systemfiler         |
| **Testat**                  | macOS Big Sur ↔ Ventura, Intel-Macar (2010 → 2019)                 |

> **Moduler som kan stängas av:** Spotlight, AirPlay, Siri, Game Controller-daemon, ReportCrash, Dashboard, visuella effekter, Time Machine-autosäkerhet, Handoff/Continuity, iCloud Photos-synk.

---

## 💾 Så installerar du (2 steg)

1. **Ladda ned & gör körbar**

   ```bash
   curl -O https://raw.githubusercontent.com/Caripson/macos-speedup-tool/main/speedup.sh
   chmod +x speedup.sh
   ```

2. **Kör**

   ```bash
   sudo ./speedup.sh         # interaktivt läge
   ```

---

## ⚡ Snabbkommandon för gurun

| Kommando                              | Gör detta                                               |
|---------------------------------------|---------------------------------------------------------|
| `sudo ./speedup.sh --auto all`        | Stäng AV allt, inga frågor                              |
| `sudo ./speedup.sh --auto spotlight,fx`| Stäng AV bara Spotlight **och** effekter               |
| `sudo ./speedup.sh --verify`          | Visa status ✅ / ❌ för varje modul                      |
| `sudo ./speedup.sh --undo timemachine`| Slå PÅ Time Machine igen                                |
| `sudo ./speedup.sh --help`            | Kort hjälp, listan över moduler                         |

---

## För dig som är 👴 

1. **Öppna Terminal**  
   (Finns i **Program → Verktygsprogram → Terminal**)

2. **Kopiera & klistra in** rad för rad:  

   ```bash
   curl -O https://raw.githubusercontent.com/Caripson/macos-speedup-tool/main/speedup.sh
   chmod +x speedup.sh
   sudo ./speedup.sh
   ```

3. **Svara “y”** på allt du vill stänga av.  
4. **Starta om datorn.** Klart!

Vill du ångra?  
Öppna Terminal igen och skriv t.ex.:

```bash
sudo ./speedup.sh --undo handoff
```

---

## ℹ️ Vanliga frågor

### “Är det farligt?”
Nej. Scriptet stänger bara av valfria tjänster via **officiella Apple-kommandon** (`launchctl`, `defaults`, `mdutil`, etc.). Allt kan återställas.

### “M1/M2-Mac?”
Detta är skrivet för **Intel-Macar**. På Apple-Silicon fungerar de flesta moduler, men inte testat fullt ut.

### “Hur ser jag att det funkade?”
Kör bara:

```bash
sudo ./speedup.sh --verify
```

Du får en lista med ✅ (avstängt) eller ❌ (fortfarande aktivt).

---

## 🛟 Ansvarsfriskrivning

Använd på egen risk. Scriptet är **open-source** – läs koden innan du kör.  
Bidrag & buggar: öppna en **Issue** eller **Pull Request**.

---

## 💖 Tack!

Gillar du verktyget? ⭐️-markera repo-t på GitHub och dela med en vän som har en långsam Mac 🧓➡️💨
