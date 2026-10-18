# powershell-qr

[English](#english) | [עברית](#עברית)

## English

A QR code generator in pure PowerShell. No modules, no `Add-Type`, no `System.Drawing`, no admin rights.
Long text is split automatically across several QR codes, and each one gets an `[i/N]` prefix.

**Output:** written to `.\QR_Output`: one SVG per QR code plus an `index.html`. On screen the HTML is a full-screen slideshow that loops through the codes (Space = pause, arrows = prev/next, Up/Down = speed, type a number + Enter = jump to that code). Printed, it gives one code per page.

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
| `-AsFile` | | Send `-Path` as a file (any type: zip, pdf, exe...) |
| `-Open` | | Open the HTML when done |

### Notes

- Encodes in byte mode as UTF-8, so Hebrew, emoji and other non-Latin text work.
- Splitting never breaks a UTF-8 character.

### File transfer

Sends any file from a locked-down PC: the sender only needs `qr.ps1`. It runs on built-in Windows PowerShell 5.1 with no admin, no install and no internet.

```powershell
powershell -ExecutionPolicy Bypass -File .qr.ps1 -Path .eport.pdf -AsFile -ErrorCorrection L -MaxVersion 10 -Mask 0 -Open
```

On the receiving side, scan the codes with `qr-scan.html` (any order). When the last code is scanned, it rebuilds the file, checks its SHA-256 and shows **Save file**.

Guidelines:
- The file is gzipped and sent as raw bytes. With `-ErrorCorrection L`, each code holds about 270 bytes at `-MaxVersion 10` and about 1,260 at `-MaxVersion 25`, so 100 KB of compressed data needs about 380 or 80 codes. Keep transfers small.
- Leave the slideshow running: the scanner takes codes in any order and ignores repeats. When only a few are left, type their numbers in the slideshow (e.g. `57` + Enter) instead of waiting for the next loop.
- Keep the code inside the scanner's viewfinder. Only the center of the camera image is read, which makes scanning faster.
- `-Mask 0` skips the automatic mask search, which makes generation about 8x faster.
- If you see **SHA-256 MISMATCH**, click Clear and scan everything again.
- `-ExecutionPolicy Bypass` on the command line applies only to that run and needs no admin.

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

**פלט:** קובץ SVG לכל קוד QR, וגם `index.html`: מצגת במסך מלא שעוברת על הקודים בלולאה (רווח = עצירה, חיצים = הקודם/הבא, למעלה/למטה = מהירות, מספר ואז Enter = מעבר לקוד הזה). בהדפסה כל קוד יוצא בעמוד נפרד. הכול נשמר בתיקייה `.\QR_Output`.

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
| `-AsFile` | | שליחת `-Path` כקובץ מכל סוג (zip, pdf, exe...) |
| `-Open` | | פתיחת קובץ ה-HTML בסיום |

### הערות

- הקידוד הוא במצב byte ב-UTF-8, כך שעברית, אימוג'י וטקסט שאינו לטיני עובדים.
- הפיצול אף פעם לא חותך תו UTF-8 באמצע.

### העברת קבצים

שליחת כל קובץ ממחשב נעול: בצד השולח צריך רק את `qr.ps1`. הסקריפט רץ על Windows PowerShell 5.1 המובנה, בלי הרשאות מנהל, בלי התקנה ובלי אינטרנט.

</div>

```powershell
powershell -ExecutionPolicy Bypass -File .qr.ps1 -Path .eport.pdf -AsFile -ErrorCorrection L -MaxVersion 10 -Mask 0 -Open
```

<div dir="rtl">

בצד המקבל סורקים את הקודים עם `qr-scan.html`, בכל סדר. אחרי הקוד האחרון הסורק בונה מחדש את הקובץ, בודק את ה-SHA-256 שלו ומציג כפתור **Save file**.

הנחיות:
- הקובץ נדחס ב-gzip ונשלח כבתים גולמיים. עם `-ErrorCorrection L`, כל קוד מכיל כ-270 בתים ב-`-MaxVersion 10` וכ-1,260 ב-`-MaxVersion 25`, כך ש-100KB אחרי דחיסה דורשים כ-380 או כ-80 קודים. כדאי להעביר קבצים קטנים.
- משאירים את המצגת רצה: הסורק מקבל קודים בכל סדר ומתעלם מכפילויות. כשנשארו רק כמה קודים, מקלידים את המספרים שלהם במצגת (למשל `57` ואז Enter) במקום לחכות לסיבוב הבא.
- מחזיקים את הקוד בתוך המסגרת של הסורק. הסורק קורא רק את מרכז התמונה מהמצלמה, וכך הסריקה מהירה יותר.
- `-Mask 0` מדלג על חיפוש המסכה האוטומטי, וכך היצירה מהירה פי 8 בערך.
- אם מופיע **SHA-256 MISMATCH**, לוחצים Clear וסורקים הכול מחדש.
- `-ExecutionPolicy Bypass` בשורת הפקודה חל רק על ההרצה הזו ולא דורש הרשאות מנהל.

### סורק (מצלמה)

**גרסה חיה: https://shlomo120.github.io/powershell-qr/qr-scan.html** (עובד גם בטלפון).
הכול רץ בדפדפן, והטקסט הסרוק לא נשלח לשום מקום.

לשימוש בלי אינטרנט, פותחים את `qr-scan.html` ב-Edge או Chrome (הקובץ `jsQR.js` צריך להיות באותה תיקייה), לוחצים **Start Camera** ומציגים את הקודים אחד אחרי השני, בכל סדר.
קודים מפוצלים `[i/N]` מתחברים אוטומטית, והסורק מציג אילו חלקים חסרים. אפשר גם לטעון תמונות במקום להשתמש במצלמה. עובד בלי אינטרנט ובלי התקנה.
מצלמות של מחשבים ניידים מתקשות בקודים צפופים, ולכן לסריקה במצלמה עדיף לייצר קודים עם `-MaxVersion` קטן יותר (למשל `10`).

</div>

---

Scanner uses [jsQR](https://github.com/cozmo/jsQR) (Apache-2.0, see `LICENSE-jsQR`).
