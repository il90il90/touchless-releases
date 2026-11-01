<div dir="rtl">

# Touchless — שרת ממסר (Relay) משלך ב-Docker

**English: [README.md](README.md)**

בדרך כלל Touchless מחבר בין הטלפון ל-AI דרך שרת הענן של Touchless. עם התיקייה הזאת השרת רץ
**על המחשב שלך**: הפקודות לטלפון לא יוצאות מהרשת הביתית, ואפשר לעבוד עם **AI מקומי ב-LM Studio**
בלי שום חשבון ענן.

</div>

```
LM Studio / אפליקציית AI ──/mcp──►  Touchless relay (Docker במחשב)  ◄──Wi-Fi── Touchless (טלפון)
```

<div dir="rtl">

זה לוקח בערך 10 דקות. בלי קוד מקור, בלי בנייה ובלי תכנות.

---

## מה צריך

| | |
|---|---|
| מחשב שנשאר דלוק | Windows 10/11, macOS או Linux (amd64). מק עם שבב Apple עובד דרך האמולציה של Docker. |
| **Docker Desktop** (Windows/macOS) או Docker Engine + Compose (Linux) | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) — מתקינים, פותחים ומחכים ל-**Engine running**. |
| טלפון אנדרואיד עם **Touchless** | [הורדת ה-APK העדכני](https://github.com/il90il90/touchless-releases/releases/latest) |
| הטלפון והמחשב **על אותו Wi-Fi** | רשת ביתית. רשת "אורחים" חוסמת לרוב מכשירים מלראות זה את זה. |
| (לא חובה) **LM Studio** | [lmstudio.ai](https://lmstudio.ai/) עם מודל שתומך ב-**Tool use** (קריאה לכלים). |

---

## שלב 1 — הורדת התיקייה

מורידים את **[touchless-docker.zip](https://github.com/il90il90/touchless-releases/releases/latest/download/touchless-docker.zip)**
ופורסים אותו לאן שרוצים (למשל `Documents\touchless-docker`).

את קובץ השרת עצמו (`touchless-relay-image.tar.gz`, כ-80MB) האשף מוריד ובודק (checksum) לבד בשלב הבא.
לא צריך להוריד אותו ידנית.

## שלב 2 — הפעלת השרת (לחיצה אחת)

- **Windows:** לחיצה כפולה על **`start.cmd`**.
- **macOS / Linux:** פותחים טרמינל בתיקייה ומריצים `chmod +x start.sh stop.sh && ./start.sh`.

האשף שואל שתי שאלות:

1. **איך הטלפון יגיע למחשב?** לוחצים **Enter** לבחירה **1 — אותו Wi-Fi** (מומלץ).
   הוא מוצא לבד את כתובת ה-IP של המחשב ברשת (למשל `192.168.1.50`).
2. **להפעיל LM Studio בלי טוקן?** עונים **y** רק אם LM Studio רץ **על המחשב הזה** וזה מחשב אישי
   שסומכים עליו (ראו [אבטחה](#אבטחה)). אחרת לוחצים Enter.

בסוף מופיעה מסגרת **WHAT TO DO NOW** עם הכתובות המדויקות לרשת שלך. משאירים את החלון פתוח לשלבים 3–5.

> Windows עשוי לשאול אם לאפשר ל-Docker גישה לרשת. מאשרים ל**רשתות פרטיות** בלבד.

## שלב 3 — בדיקה שהטלפון מגיע למחשב

ב**טלפון** פותחים את הדפדפן ונכנסים לכתובת מהמסגרת, עם `/healthz` בסוף:

</div>

```
http://192.168.1.50:8787/healthz
```

<div dir="rtl">

צריך להופיע **`ok`**. אם הדף לא נטען — עוברים ל[הטלפון לא מתחבר](#הטלפון-לא-מתחבר) לפני שממשיכים.

## שלב 4 — לחבר את Touchless לשרת שלך

בטלפון:

1. **Touchless ← Settings ← Advanced ← Relay server**.
2. לוחצים **Custom / self-hosted**.
3. **Relay address:** `http://192.168.1.50:8787` (ה-IP שלך מהמסגרת, **בלי** `/mcp` בסוף).
4. מדליקים **Allow LAN-only cleartext (http/ws)** — חובה לכתובת `http://` של רשת ביתית.
5. לוחצים **Save & connect**.

Touchless מתחבר מחדש למחשב שלך. במסך הבית של Touchless המתג **AI agent** צריך להישאר **On**.

> המסך הזה מוגן: AI לא יכול לשנות אותו בשבילך. את השלב הזה עושים ביד, פעם אחת.

## שלב 5 — חיבור LM Studio (לא חובה)

1. ב-LM Studio מורידים וטוענים מודל שתומך בקריאה לכלים (למשל Qwen 3 / Qwen 3.5 instruct).
   בהגדרות הטעינה מעלים את **Context Length** ל-**16384** לפחות (ל-Touchless יש הרבה כלים).
2. פותחים **Program ← Install ← Edit mcp.json** ומוסיפים רשומה בשם `touchless`. שרתים אחרים שכבר יש — משאירים.

**אם ענית "y" ל-LM Studio בלי טוקן:**

</div>

```json
{
  "mcpServers": {
    "touchless": { "url": "http://127.0.0.1:8788/mcp" }
  }
}
```

<div dir="rtl">

**אחרת (מפתח API, עובד מכל מחשב ב-Wi-Fi שלך):**

1. בטלפון (אחרי שלב 4): **Touchless ← Settings ← AI connection ← Copy address**. הכתובת נראית עכשיו כך:
   `http://192.168.1.50:8787/mcp/abc123…` (השרת שלך + המזהה של הטלפון).
2. באותו מסך ← **Advanced ← API key**: כותבים שם (למשל *LM Studio*), יוצרים ומעתיקים את המפתח (`tlk.…`).
   הוא מוצג **פעם אחת בלבד** — שומרים עליו כמו על סיסמה.
3. ב-`mcp.json`:

</div>

```json
{
  "mcpServers": {
    "touchless": {
      "url": "http://192.168.1.50:8787/mcp/PASTE-YOUR-DEVICE-ID",
      "headers": { "Authorization": "Bearer tlk.PASTE-YOUR-API-KEY" }
    }
  }
}
```

<div dir="rtl">

לעולם לא מפרסמים את המפתח ולא שמים אותו בכתובת. אפשר לבטל אותו בכל רגע באותו מסך.

3. שומרים, מוודאים שהאינטגרציה **touchless** דולקת בצ'אט, ושואלים:
   *"Call the Touchless get_device_info tool and tell me only what it returns."*
   צריך לחזור דגם הטלפון ואחוז הסוללה.

אם LM Studio אומר שהבקשה גדולה מה-context: מעלים **Context Length**, או מכבים כלים שלא צריך ברשימת הכלים של האינטגרציה.

---

## שימוש יומיומי

| רוצים… | Windows | macOS / Linux |
|---|---|---|
| להפעיל שוב (אחרי הפעלה מחדש של המחשב הוא עולה לבד) | `start.cmd` | `./start.sh` |
| לעצור | `stop.cmd` | `./stop.sh` |
| לעדכן לגרסה החדשה | `start.cmd update` | `./start.sh update` |
| לראות לוג | `docker compose logs -f relay` | אותו דבר |
| לחזור לענן של Touchless | Touchless ← Settings ← Advanced ← Relay server ← **Touchless cloud (Default)** | אותו דבר |

ההגדרות נשמרות ב-`.env`, והמצב הקטן של השרת ב-volume של Docker בשם `relay-data`. עצירה ועדכון שומרים את שניהם.
`docker compose down -v` **מוחק** את ה-volume — בדרך כלל לא רוצים את זה.

### פקודות ידניות (במקום האשף)

</div>

```bash
cp .env.example .env                 # ואז ב-.env: RELAY_LAN_IP=<ה-IP של המחשב ב-Wi-Fi>
docker load -i touchless-relay-image.tar.gz
docker compose -f docker-compose.yml -f docker-compose.lan.yml up -d
# להוסיף  -f docker-compose.local-mcp.yml  עבור LM Studio בלי טוקן
```

<div dir="rtl">

## מה יש בתיקייה

| קובץ | מה הוא עושה |
|---|---|
| `start.cmd` / `start.ps1` | האשף ל-Windows: מוריד ובודק את השרת, כותב `.env`, מפעיל ומדפיס כתובות. |
| `start.sh` | אותו אשף ל-macOS / Linux. |
| `stop.cmd` / `stop.sh` | עוצר את השרת (הנתונים נשמרים). |
| `docker-compose.yml` | השרת עצמו, נגיש רק מהמחשב הזה (`127.0.0.1:8787`). |
| `docker-compose.lan.yml` | מוסיף את ה-IP של ה-Wi-Fi כדי שהטלפון יתחבר. |
| `docker-compose.local-mcp.yml` | לא חובה: LM Studio במחשב הזה בלי טוקן (`127.0.0.1:8788`). |
| `docker-compose.tls.yml` + `Caddyfile` | לא חובה: HTTPS ציבורי עם דומיין משלך (ל-ChatGPT / Claude בענן). |
| `.env.example` | כל ההגדרות עם הסבר. האשף מעתיק אותו ל-`.env`. |

## AI בענן (ChatGPT, Claude באתר)

AI בענן רץ באינטרנט ו**לא יכול** להגיע לכתובת `192.168.x.x`. האפשרויות:

- להמשיך עם שרת **הענן של Touchless** (הכי פשוט), או
- להריץ `start.cmd public` / `./start.sh public` עם **דומיין משלך** שה-DNS שלו מצביע על המחשב, ופורטים 80/443 פתוחים אליו.
  Caddy מוציא תעודת HTTPS בחינם אוטומטית. ב-Touchless כותבים `https://הדומיין-שלך` (מתג ה-cleartext **כבוי**),
  ונותנים ל-AI את הכתובת מ-**Touchless ← Settings ← AI connection**.
- רק למכשירים שלך: VPN (Tailscale / WireGuard) חוסך פתיחת פורטים.

## הטלפון לא מתחבר

עוברים לפי הסדר:

1. **אותה רשת?** הטלפון חייב להיות על אותו Wi-Fi כמו המחשב — לא גלישה סלולרית ולא רשת אורחים.
2. **IP נכון?** מריצים `ipconfig` (Windows) ולוקחים את ה-IPv4 של מתאם ה-**Wi-Fi**. לא `127.0.0.1` ולא `172.x`
   (זה Docker/WSL). אם ה-IP השתנה — מריצים שוב `start.cmd lan` ומעדכנים בטלפון.
3. **הרשת ב-Windows מוגדרת פרטית?** ב-PowerShell: `Get-NetConnectionProfile`. אם ה-Wi-Fi הביתי מופיע כ-*Public*,
   פותחים PowerShell **כמנהל**: `Set-NetConnectionProfile -InterfaceIndex <מספר> -NetworkCategory Private`
4. **חומת האש של Windows** — ב-PowerShell **כמנהל**:

</div>

```powershell
New-NetFirewallRule -DisplayName "Touchless relay 8787" -Direction Inbound -Protocol TCP -LocalPort 8787 -RemoteAddress LocalSubnet -Profile Private -Action Allow
```

<div dir="rtl">

   macOS: System Settings ← Network ← Firewall ← לאשר את Docker. Linux (ufw): `sudo ufw allow from 192.168.0.0/16 to any port 8787 proto tcp`.

5. **הפורט מופיע?** `docker ps` צריך להראות `<ה-IP שלך>:8787->8787/tcp`. אם רואים רק `127.0.0.1:8787` — הופעל
   בלי מצב רשת: מריצים `start.cmd lan`.
6. **Touchless אומר שהכתובת לא מוצפנת:** מדליקים **Allow LAN-only cleartext (http/ws)**.

| הודעה | פירוש |
|---|---|
| `No phone connected. Connect Touchless first.` (ב-LM Studio) | השרת רץ אבל הטלפון עוד לא מחובר אליו: לסיים את שלב 4 ולהשאיר **AI agent** דולק. |
| `401` | מפתח API שגוי, מבוטל או חסר ב-`Authorization`, או שהכתובת אינה זו מ-**Copy address**. |
| `403` | רשימת **IP access** ב-Touchless חוסמת את המחשב: Settings ← Safety & approvals. |
| השם `touchless-relay` כבר תפוס | עותק אחר של השרת רץ: לעצור אותו קודם (`docker stop touchless-relay`). |
| הפורט תפוס | לשנות `RELAY_PORT` ב-`.env` ולהפעיל שוב. |
| ההורדה נכשלת מאחורי פרוקסי ארגוני | להוריד את `touchless-relay-image.tar.gz` ואת `.sha256` מדף הגרסאות לתוך התיקייה ולהריץ שוב את האשף. |

## אבטחה

- השרת מאזין **למחשב הזה** בלבד, ובמצב רשת — **רק על ה-IP של ה-Wi-Fi שלך**, אף פעם לא על כל הממשקים.
  **לעולם לא לפתוח (port-forward) את 8787 או 8788 בראוטר.**
- `http://` ברשת ביתית אינו מוצפן. רק ב-Wi-Fi ביתי שסומכים עליו; לכל השאר — HTTPS.
- לקוחות AI נכנסים בהתחברות שמאשרים בטלפון או במפתח API שיוצרים ב-Touchless ואפשר לבטל.
  השרת שומר רק hash ולעולם לא מדפיס טוקנים או מפתחות.
- **LM Studio בלי טוקן** (`127.0.0.1:8788`) מאפשר **לכל תוכנה במחשב הזה** לשלוט בטלפון המחובר.
  להפעיל רק במחשב אישי שסומכים עליו, ולעולם לא לחשוף את הפורט הזה.
- הגדרות הבטיחות של Touchless (מצב אישורים, מסכים מוגנים, IP access, שעות פעילות) חלות בדיוק כמו בענן.

</div>
