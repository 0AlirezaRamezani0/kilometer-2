# 🤖 AGENTS.md — راهنمای کار روی این مخزن (Kilometer 2 / K2)

> این فایل برای **عامل‌های هوش مصنوعی** (Arena Agent Mode، Claude Code، Cursor، Codex و…) نوشته شده
> تا در چند ثانیه پروژه را بشناسند و بدون حدس‌زدن، درست دست به کد بزنند.
> زبان پروژه: **انگلیسی** برای کد/داده/کامیت، **فارسی** برای رشته‌های رابط کاربری.

---

## 1. این پروژه چیست؟

| مورد | مقدار |
|---|---|
| نام محصول | **Kilometer 2** (برند: `KILOMETER`، کوتاه: `K2`) |
| نوع | بازی سه‌بعدی مسابقه‌ای/رانندگی، رابط **فارسی (RTL)** |
| موتور | **Godot 4.7.2-stable** (تگ ویژگی `4.7`) — با Godot 3.x باز نکنید |
| رندرر | `gl_compatibility` (دسکتاپ + اندروید) |
| فیزیک | **Jolt**, 60 tick/s |
| زبان | فقط **GDScript** (بدون .NET، بدون افزونه/پلاگین/ساب‌ماژول) |
| نسخه فعلی سورس | `v0.2-b6-clean-road` (کد ۱۲) |
| رزولوشن مرجع | 1280×720، `canvas_items` stretch |
| پلتفرم‌ها | دسکتاپ + اندروید (preset اکسپورت آماده) |

**حلقه بازی:** انتخاب خودرو در نمایشگاه سه‌بعدی (`main_menu.tscn`) → رانندگی در پیست بیابانی ۹۷۳ متری
(figure-eight) → زمان‌سنجی دور، ۱۲ چک‌پوینت سکتور، شمارش معکوس چراغ شروع → منوی توقف/تنظیمات/چندنفره LAN.

---

## 2. نقشه پوشه‌ها (کجا چه چیزی را تغییر دهم)

```
project.godot            پیکربندی موتور: main scene، ورودی‌ها، رندرر، فیزیک، اتولودها
export_presets.cfg       preset اکسپورت اندروید (نام نمایشی، versionCode، id)
README.md                معرفی محصول، نصب، اجرا، تست
CHANGELOG.md             تاریخچه تغییرات نسخه‌ها — هر تغییر کاربری باید اینجا ثبت شود
LICENSES.md              مجوز کد (MIT) + مجوز دارایی‌ها (فونت‌ها OFL، مدل‌ها CC BY-NC)
THIRD_PARTY_ASSETS.md    منبع/مجوز تک‌تک دارایی‌های ثالث + الزامات انتساب
documentation/           ARCHITECTURE, DEVELOPMENT, DESIGN_SYSTEM, UX_ARCHITECTURE,
                         DESERT_CIRCUIT, ASSET_CATALOG, TESTING, MAINTENANCE, CLEANUP_REPORT
scenes/                  صحنه‌ها: ui/ main/ vehicle/ track/ camera/ preview/
scripts/                 آینه‌ی ساختار scenes/ — هر .tscn لاغر است (فقط root + script)
assets/fonts/            Estedad + Changa (OFL-1.1)  ·  assets/vehicle/  GLB خودروها
assets/track/            GLB پیست + centreline.json (نقشه‌برداری‌شده)
assets/environment/      دیوراما‌ی گاراژ بیابانی (garage_desert.glb)
tests/                   ۱۷ سوییت هدلس (GDScript SceneTree)
qa/                      run_tests.sh، اسکریپت‌های کپچر (توسعه‌ای، از اکسپورت حذف‌شده)
tools/                   sync_version.py، بهینه‌ساز GLB، survey پیست
```

**قاعده طلایی:** منطق در `scripts/` است، صحنه‌ها فقط صحنه‌اند. ساختار `scripts/` باید آینه‌ی `scenes/` بماند.

---

## 3. اجرا و تست (بدون حدس زدن)

```bash
# ایمپورت پروژه (بار اول اجباری)
godot --headless --path . --import

# اجرا از خط فرمان
godot --path .

# اجرای کل تست‌ها با خلاصه
GODOT_BIN=/path/to/godot bash qa/run_tests.sh

# اجرای یک سوییت
godot --headless --path . --script res://tests/test_project_integrity.gd

# فقط تست‌های یک حوزه
bash qa/run_tests.sh -k desert
```

قبل از هر کامیت: **کل تست‌ها باید ۰ خطا بدهند** (وضعیت شناخته‌شده: ۸۸۱+ چک، ۰ خطا).
اگر تستی می‌شکند، کد را «دور نزنید»؛ تست را با دلیل معتبر آپدیت کنید و در `CHANGELOG.md` بنویسید.

---

## 4. قاعده‌های کدنویسی (اجباری)

- **GDScript با تایپ ایستا** تا جای ممکن؛ `class_name` برای انواع مشترک
  (`VehicleCatalog`, `SettingsManager`, `UiTheme`, کنترلرها).
- **هیچ رنگ/استایل محلی در صفحه‌ها نسازید.** فقط توکن‌های معنایی:
  `UiTheme.COLOR_ACCENT / OK / WARN / DANGER / MUTED / TEXT`؛ چیدمان با factory های `UiTheme`.
- نام‌گذاری: `snake_case` برای فایل/تابع/متغیر، `PascalCase` برای کلاس‌ها،
  صحنه‌ها هم‌نام با اسکریپت root (`vehicle_hud.tscn` ↔ `scripts/ui/vehicle_hud.gd`).
- کامنت‌ها **چرایی** را بگویند (invariant، باگ قبلی)، نه چگونگی.
- رشته‌های فارسی در اسکریپت‌های UI؛ RTL فقط روی container های متنی، **اعداد تلماتری لاتین**.
- **یک پیاده‌سازی معتبر برای هر سیستم**: UI، دوربین، تنظیمات، خودرو، ورودی. اگر انگار دو نسخه وجود دارد،
  یکی اشتباه است — قبل از افزودن سیستم جدید، `documentation/ARCHITECTURE.md` را بخوانید.

### invariant های حساس (نقض نکنید)
1. تنظیمات فقط از `SettingsManager` می‌آید؛ گرافیک فقط در شروع صحنه یا تغییر صریح کاربر اعمال می‌شود.
2. انتخاب خودرو فقط در نمایشگاه منو انجام می‌شود و برای کل سشن قفل است.
3. یک دوربین تعقیب‌کننده (`SpringArm3D`) — حالت دوم/سوییچ نداریم.
4. `version_info.gd` تنها منبع نسخه است؛ سپس `python3 tools/sync_version.py`.
5. هیچ گیت‌دار‌ها/نوارهای ایمن **کشیده نمی‌شوند** (دیوارهای نامرئی برخورد دارند، اما رسم نمی‌شوند).

---

## 5. دارایی‌ها و مجوزها (قبل از هر انتشار تجاری بخوانید)

- کد و محتوای رویه‌ای: **MIT**.
- فونت‌ها: **OFL-1.1** (Estedad, Changa, Vazirmatn).
- دیورامای «Car Garage | Desert Garage Environment» اثر **DevPoly3D** → **CC BY-NC 4.0**:
  ذکر انتساب اجباری است و **برای انتشار تجاری به‌همان‌شکل مجاز نیست**؛
  نسخه جایگزین: `-- --hangar-stage` (صحنه رویه‌ای v0.1-b3).
- مدل خودروها: شرایط در `LICENSES.md`. قبل از اضافه‌کردن دارایی جدید، ردیف آن را در
  `THIRD_PARTY_ASSETS.md` + `LICENSES.md` اضافه کنید.
- **هیچ‌گاه** کلید/رمز/فایل keystore در مخزن نگذارید (امضا در `.godot/export_credentials.cfg`، git-ignored).

---

## 6. چه چیزی کامیت نمی‌شود

`.godot/` (کش ایمپورت)، `export/`, `build/`, `*.apk`, `*.aab`، فایل‌های رمزنگاری/امضا،
`.claude/` (تنظیمات ابزار محلی). `.gitignore` از قبل همین‌ها را پوشش می‌دهد.

---

## 7. سبک کار مورد انتظار از عوامل هوش مصنوعی

1. **اول بخوان، بعد بنویس:** `README.md` → `documentation/ARCHITECTURE.md` → فایل مرتبط در `scripts/`.
2. **تغییر کوچک و متمرکز** بده؛ یک commit = یک تغییر منطقی، پیام انگلیسی وصفی.
3. **همیشه تست‌ها را اجرا کن** و نتیجه را در پاسخ گزارش بده (`bash qa/run_tests.sh`).
4. اگر تغییر کاربری دارد → `CHANGELOG.md`؛ اگر سیستم/معماری را تغییر می‌دهد → `documentation/`.
5. نسخه را دستی در چند جا تغییر نده؛ فقط `scripts/ui/version_info.gd` + `tools/sync_version.py`.
6. اگر ابزاری در دسترس نبود (مثلاً Godot نصب نبود) صادقانه بگو و فقط تغییرات متنی/ساختاری بده.

---

## 8. نقشه سیستم‌ها → فایل‌ها

| سیستم | فایل اصلی |
|---|---|
| HUD و تلماتری | `scripts/ui/vehicle_hud.gd` (≈۷۲k) |
| منوی اصلی + نمایشگاه | `scripts/ui/main_menu.gd` (≈۷۰k) |
| تم/طراحی «Proving Ground» | `scripts/ui/ui_theme.gd` |
| صفحه کلاستر فارسی | `scripts/ui/persian_gauge_cluster.gd` |
| تنظیمات | `scripts/ui/settings_manager.gd` |
| کنترل خودرو (Jolt) | `scripts/vehicle/saipa_vehicle_controller.gd` |
| مدل بصری خودرو | `scripts/vehicle/saipa_visual_model.gd` |
| کاتالوگ شش خودرو | `scripts/vehicle/vehicle_catalog.gd` |
| دوربین تعقیب | `scripts/camera/vehicle_camera_rig.gd` |
| پیست بیابانی | `scripts/track/desert_circuit.gd` |
| چندنفره LAN | `scripts/multiplayer/lan_session.gd`, `lan_lobby.gd`, `lan_game.gd` |
| صدا | `scripts/audio/audio_manager.gd`, `scripts/vehicle/engine_audio.gd` |
| ورودی (کیبورد/گیم‌پد/تاچ) | `scripts/vehicle/vehicle_input_map.gd`, `scripts/ui/input_device_manager.gd` |

---

*آخرین به‌روزرسانی این راهنما: همگام با `K2_SOURCE_v0.2-b6-clean-road`.*
