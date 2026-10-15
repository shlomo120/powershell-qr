# powershell-qr

[English](#english) | [עברית](#עברית)

## English

A QR code generator in pure PowerShell. No modules, no `Add-Type`, no `System.Drawing`, no admin rights.
Long text is split automatically across several QR codes, and each one gets an `[i/N]` prefix.

**Output:** one SVG per QR code plus an `index.html` (one code per printed page), written to `.\QR_Output`.

### Usage

```powershell
.\qr.ps1 -Text "Hello world" -Open
.\qr.ps1 -Path .\long.txt -ErrorCorrection L -MaxVersion 20 -Open
powershell -ExecutionPolicy Bypass -File .\qr.ps1 -Path .\notes.txt
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Text` | | Text to encode (or use `-Path`) |
| `-Path` | | UTF-8 text file to encode |
| `-ErrorCorrection` | `M` | `L`, `M`, `Q` or `H` |
| `-MaxVersion` | `25` | Largest QR version per code (1-40; 25 = 117x117 modules) |
| `-OutDir` | `.\QR_Output` | Output folder |
| `-ModulePx` | `6` | Pixel size of each module in the SVG |
| `-Mask` | `-1` | `-1` = auto (lowest penalty), `0`-`7` = fixed mask (faster) |
| `-NoHeader` | | Don't add the `[i/N]` prefix when splitting |
| `-Eci` | | Add an ECI 26 (UTF-8) header, for older scanners |
| `-Open` | | Open the HTML when done |

### Notes

- Encodes in byte mode as UTF-8, so Hebrew, emoji and other non-Latin text work.
- Splitting never breaks a UTF-8 character.

### Scanner (camera)

**Live: https://shlomo120.github.io/powershell-qr/qr-scan.html** (works on phones too).
Everything runs in your browser and the scanned text is never uploaded.

To use it offline, open `qr-scan.html` in Edge or Chrome (keep `jsQR.js` next to it), click **Start Camera**, and show the codes one by one in any order.
Multi-part `[i/N]` codes are joined automatically and the missing parts are listed. You can also load images instead of using the camera. Works offline, nothing to install.
Laptop webcams struggle with dense codes, so for camera scanning generate with a smaller `-MaxVersion` (e.g. `10`).

---

<div dir="rtl">

## עברית

מחולל קודי QR ב-PowerShell טהור. לא צריך מודולים, `Add-Type`, `System.Drawing` או הרשאות מנהל.
טקסט ארוך מתפצל אוטומטית לכמה קודי QR, ולכל אחד מתווספת קידומת `[i/N]`.

**פלט:** קובץ SVG לכל קוד QR, וגם `index.html` שבו כל קוד בעמוד הדפסה נפרד. הכול נשמר בתיקייה `.\QR_Output`.

### שימוש

</div>

```powershell
.\qr.ps1 -Text "שלום עולם" -Open
.\qr.ps1 -Path .\long.txt -ErrorCorrection L -MaxVersion 20 -Open
powershell -ExecutionPolicy Bypass -File .\qr.ps1 -Path .\notes.txt
```

<div dir="rtl">

### פרמטרים

| פרמטר | ברירת מחדל | תיאור |
|---|---|---|
| `-Text` | | הטקסט לקידוד (או `-Path`) |
| `-Path` | | קובץ טקסט בקידוד UTF-8 |
| `-ErrorCorrection` | `M` | רמת תיקון שגיאות: `L`, `M`, `Q` או `H` |
| `-MaxVersion` | `25` | גרסת ה-QR המקסימלית לכל קוד (1-40; גרסה 25 היא 117x117 מודולים) |
| `-OutDir` | `.\QR_Output` | תיקיית הפלט |
| `-ModulePx` | `6` | גודל כל מודול בפיקסלים ב-SVG |
| `-Mask` | `-1` | `-1` = בחירה אוטומטית (הניקוד הנמוך ביותר), `0`-`7` = מסכה קבועה (מהיר יותר) |
| `-NoHeader` | | בלי קידומת `[i/N]` בפיצול |
| `-Eci` | | הוספת כותרת ECI 26 (UTF-8) לסורקים ישנים |
| `-Open` | | פתיחת קובץ ה-HTML בסיום |

### הערות

- הקידוד הוא במצב byte ב-UTF-8, כך שעברית, אימוג'י וטקסט שאינו לטיני עובדים.
- הפיצול אף פעם לא חותך תו UTF-8 באמצע.

### סורק (מצלמה)

**גרסה חיה: https://shlomo120.github.io/powershell-qr/qr-scan.html** (עובד גם בטלפון).
הכול רץ בדפדפן, והטקסט הסרוק לא נשלח לשום מקום.

לשימוש בלי אינטרנט, פותחים את `qr-scan.html` ב-Edge או Chrome (הקובץ `jsQR.js` צריך להיות באותה תיקייה), לוחצים **Start Camera** ומציגים את הקודים אחד אחרי השני, בכל סדר.
קודים מפוצלים `[i/N]` מתחברים אוטומטית, והסורק מציג אילו חלקים חסרים. אפשר גם לטעון תמונות במקום להשתמש במצלמה. עובד בלי אינטרנט ובלי התקנה.
מצלמות של מחשבים ניידים מתקשות בקודים צפופים, ולכן לסריקה במצלמה עדיף לייצר קודים עם `-MaxVersion` קטן יותר (למשל `10`).

</div>

---

Scanner uses [jsQR](https://github.com/cozmo/jsQR) (Apache-2.0, see `LICENSE-jsQR`).
