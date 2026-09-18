# VIOLET SCAN

**SCAN LONGER. GET BETTER**

Нативное iOS-приложение (SwiftUI + ARKit) для LiDAR-сканирования с **накопительным fusion**: повторный проход **не портит** уже хорошую геометрию.

> Bundle ID: `com.violetscan.app`  
> MVP собран на Linux (без Xcode). IPA — через GitHub Actions + Sideloadly (как HalfDot / RoomLive).

---

## Философия

1. **Accumulative fusion** — пространственная сетка (`ConfidenceGrid` / `VoxelStore`) хранит лучший сэмпл + confidence.
2. **Merge policy** — keep if worse · improve if better · add if new · never blind replace.
3. **Lock good data** — ячейки выше порога **замораживаются**; слабые зоны идут в Precision Pass.
4. **MAX QUALITY** — мелкий шаг ячейки, высокий lock-порог, больше сэмплов глубины (цена: место на диске).

Крупные отверстия **не** автозаполняются (`HoleDetector` только классифицирует).

---

## Что умеет MVP

| Модуль | Статус |
|--------|--------|
| ConfidenceGrid merge + lock | ✅ рабочая логика |
| ScanEngine ARSession + sceneDepth + mesh anchors | ✅ накопление в одну модель, pause/resume |
| AutoProtect / LockGoodData | ✅ |
| Precision Pass (ранжирование слабых зон, %) | ✅ UI + прогресс |
| Guidance (green/yellow/red/purple + RU-подсказки) | ✅ rule-based |
| HoleDetector small/medium/large | ✅ без fill large |
| QualityScore | ✅ эвристика |
| ProjectStore Raw/Passes/Fused/Mesh/Texture/Final | ✅ |
| FinalReconstruction staged UI | ✅ упрощённый export |
| Export OBJ + USDA | ✅ · PLY/STL/GLB — stub в UI |
| Settings FAST…MAX + storage warning | ✅ |
| LiDAR check on launch | ✅ |

**Честные TODO (не заявлены как готовые):** plane-fitting, Metal/TSDF fusion, Poisson, полноценный `.usdz` пакет, UV/текстурный атлас.

---

## Устройства

Нужен **LiDAR**: iPhone 12/13/14/15/16 Pro (и Pro Max), iPad Pro с LiDAR.  
Без LiDAR UI откроется с предупреждением; scene reconstruction / sceneDepth могут быть недоступны.

---

## Сборка на Mac (XcodeGen)

```bash
brew install xcodegen
git clone https://github.com/dilukliu0-cyber/violet-scan.git
cd violet-scan
./Scripts/setup-xcode.sh   # или: xcodegen generate
open VioletScan.xcodeproj
```

В Xcode: выберите Team для Signing → Run на устройстве с LiDAR (iOS 16+).

---

## IPA без Mac (GitHub Actions + Sideloadly)

Токен OAuth часто **без** scope `workflow`, поэтому workflow лежит в репозитории как шаблон:

**`Scripts/github-build-ipa.yml`**

### Как включить (один раз)

**Вариант A — веб-UI GitHub**

1. Откройте репозиторий → **Actions** → **New workflow** → *set up a workflow yourself*.
2. Скопируйте содержимое `Scripts/github-build-ipa.yml` в `.github/workflows/build-ipa.yml`.
3. Commit на `main`.

**Вариант B — токен с `workflow`**

```bash
mkdir -p .github/workflows
cp Scripts/github-build-ipa.yml .github/workflows/build-ipa.yml
git add .github/workflows/build-ipa.yml
git commit -m "ci: enable unsigned IPA workflow"
git push
```

### Скачать IPA

1. Actions → **Build IPA** → Run workflow (или дождитесь push на `main`).
2. Artifact: **VioletScan-unsigned-ipa**.
3. Установите через **[Sideloadly](https://sideloadly.io/)** (Apple ID). Unsigned build требует переподписи Sideloadly.

---

## Экраны

- **Home** — VIOLET SCAN · START SCAN · режим качества · недавние проекты  
- **Scan** — live ARView · покрытие/качество · ПАУЗА / LOCK / PRECISION / FINISH  
- **Precision Pass** — список слабых зон · фиолетовый акцент · % → ЗОНА ЗАВЕРШЕНА  
- **Result** — меш / каркас / текстура(stub) · экспорт  
- **Settings** — FAST / BALANCED / HIGH / MAX QUALITY + предупреждение о памяти  

---

## Структура

```
project.yml                 # XcodeGen
VioletScan/                 # App + UI + ScanEngine
VioletScanShared/           # ConfidenceGrid, export, store, guidance…
Scripts/github-build-ipa.yml
Scripts/setup-xcode.sh
```

Диски проекта: `Documents/VioletScanProjects/<uuid>/{Raw,Passes,Fused,Mesh,Texture,Final}`.

---

## Лицензия / автор

Woilet / dilukliu0-cyber — MVP для серьёзного spatial-сканирования, не «неоновая игрушка».
