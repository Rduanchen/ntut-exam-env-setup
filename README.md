# 北科大程式設計考試環境 (NTUT Exam Environment Setup)

本專案為北科大程式設計考試系統的整合部署與環境配置工具。提供自動化腳本，能協助您快速完成主機系統 (`host`)、評測機 (`Piston`) 與學生端 (`desktop`) 的環境建置與組態同步。

---

## 系統需求 (Prerequisites)

- **Node.js**：**Node.js >= 20.19.0**（若主系統選擇非 Docker 部署為必備；因後端 CommonJS 載入 ESM 套件需支援）。
- **Docker Desktop**：必備（無論主系統是否使用 Docker，Piston 程式碼沙盒評測機均依賴 Linux 隔離容器運行）。
- **Git Bash**：Windows 使用者強烈建議，且建議以**系統管理員身分**執行（以利自動配置 Windows 防火牆允許區域網路連線）。
- **pnpm**：`pnpm >= 9`（主系統專案採用 pnpm workspace 管理）。

---

## 專案結構說明

本環境部署工具設計可相容以下目錄佈局：
```text
ntut-exam-v2/
├── host/                     # 考試主系統 (後端 Express + 前端 Vue)
├── desktop/                  # 學生端桌面應用程式 (Electron + Vue)
└── ntut-exam-env-setup/       # 本部署專案
    ├── setup.sh              # 核心互動式自動部署與環境設定腳本
    ├── start-host.sh         # 主機系統啟動腳本 (檢查 Piston 並啟動 host)
    ├── piston.sh             # Piston 容器啟動與語言套件安裝工具
    ├── build-desktop.sh      # 學生端程式打包與同步工具
    ├── docker-compose.yaml   # Piston 評測機獨立 Docker 設定
    └── client-setting/       # 學生端派送包 (含腳本、檢測工具與 pre_settings.json)
```

---

## 快速自動化部署 (Quick Setup)

在終端機（Windows 請開啟 Git Bash，建議以管理員身分執行）執行：

```bash
bash setup.sh
```

### 互動式設定流程：

1. **專案定位**：自動偵測同層或子目錄下的 `host` 與 `desktop` 專案，若未下載可自動由 GitHub clone。
2. **通訊埠與伺服器 IP 設定**：
   - 後端 API Port（預設 `3000`）
   - 前端網站 Port（預設 `5173`）
   - Piston 評測服務 Port（預設 `2000`）
   - 伺服器對外 / 區網 IP：腳本會自動偵測本機真實 IP，並將此 IP 注入前端設定與學生端 `pre_settings.json`，確保教室區網內的電腦均能正常連線。
3. **安全金鑰 (Admin Token)**：
   - 系統依據新版規格採用 `ADMIN_TOKEN` 驗證（相容舊版 `ADMIN_SECRET`）。可手動輸入或由腳本自動產生 32 字元安全亂數。
4. **選擇部署模式**：
   - **[1] Docker 完整部署 (推薦)**：
     - 前端、後端與 Piston 均封裝於容器中運行。
     - 完整保留 `host/docker-compose.yml` 之生產環境調校（含 tmpfs 任務目錄、沙盒限制與持久化儲存）。
     - 啟動指令：`docker compose -f host/docker-compose.yml up -d --build`
   - **[2] 本機 Node.js 部署**：
     - 自動檢查本機 Node.js 版本（確保 `>= 20.19.0`）。
     - 自動產生 `host/backend/.env` 與 `host/frontend/.env`。
     - 自動啟動 Piston 容器，並透過 `pnpm install` 與 `pnpm build` 建置系統。
     - 支援以 **PM2** 常駐於背景運行，或以手動指令前台執行。
5. **Windows 防火牆設定**：以管理員身分執行時，會自動透過 `netsh` 開放指定 TCP Port。
6. **Piston 評測機語言套件安裝**：
   - 提供互動選單快速安裝：`Python (3.12.0)` 與 `GCC (C/C++ 10.2.0)`。
7. **學生端設定自動同步**：
   - 自動更新 `client-setting/pre_settings.json` 的 `remoteHost` 為伺服器真實 IP 與 Port。
   - 若 `desktop` 已編譯 Windows 安裝檔，自動複製至 `client-setting/ntut-code-tester.exe`。

---

## Piston 評測機維護 (`piston.sh`)

Piston 是執行學生提交程式碼的沙盒引擎。本專案已套用官方優化參數：
- **編譯逾時上限**：`PISTON_COMPILE_TIMEOUT=30000`（30 秒，避免被主系統逾時拒絕）。
- **最大輸出大小**：`PISTON_OUTPUT_MAX_SIZE=65536`（64 KB，保留完整編譯診斷）。
- **沙盒隔離**：`privileged: true` 與 tmpfs 掛載 `/piston/jobs`。
- **持久化保存**：語言包保存於 Docker volume，重啟不需重新下載。

### 常用指令：

```bash
# 啟動 Piston 並自動安裝 Python 與 GCC
bash piston.sh

# 自訂安裝指定語言 (例如加入 Java)
bash piston.sh python gcc java
```

---

## 主系統服務管理 (若選擇本機 Node.js 部署)

### 方式 A：透過 PM2 管理 (背景常駐)

- **查看運行中服務**：`pm2 list`
- **查看即時日誌**：`pm2 logs` (或 `pm2 logs ntut-backend`)
- **重啟服務**：`pm2 restart ntut-backend` 或 `pm2 restart ntut-frontend`
- **停止服務**：`pm2 stop all`
- **刪除服務**：`pm2 delete all`

### 方式 B：手動指令啟動

```bash
# 透過整合腳本 (會先確認 Piston 運行後啟動 host)
bash start-host.sh

# 或直接在 host 目錄下
cd host
pnpm start
```

---

## 學生端應用程式 (`desktop`) 打包與派送

學生端應用程式為基於 Electron 開發之客戶端。

### 1. 打包學生端安裝檔 (`build-desktop.sh`)

在 Windows 環境或具備 Wine 的環境下：

```bash
bash build-desktop.sh
```

- 選項 `1`：進入 `desktop` 執行 `npm run build:win`，產出安裝檔並自動同步至 `client-setting/ntut-code-tester.exe`。
- 選項 `2`：僅將 `desktop/dist` 現有安裝檔同步至 `client-setting/`。
- 選項 `3`：將 `client-setting/` 壓縮為 `client-deploy.zip`，方便直接派送至廣播軟體。

---

### 2. 學生電腦遠端控制與派送指南 (使用廣播軟體)

#### 步驟 A：一鍵自動化安裝與環境檢測 (推薦)

將 `client-setting` 資料夾派送到學生電腦（例如桌面），在學生電腦上以管理員身分執行：

```bat
"%USERPROFILE%\Desktop\client-setting\test-deploy-v2.bat"
```

此腳本將自動執行：
1. **執行 `test-v2.ps1` 進行環境測試**：檢測 VS Code、VMware、Code::Blocks、C/C++ 編譯器（gcc/g++/clang 指標與記憶體測試）以及 Python 執行環境。
2. **自動安裝 `ntut-code-tester.exe`**。
3. **部署 `pre_settings.json`** 至應用程式目錄。
4. **背景靜默啟動 `NTUTOnMachineTest.exe`**。

---

#### 步驟 B：手動分步指令

1. **安裝學生端程式**：
   ```bat
   "%USERPROFILE%\Desktop\ntut-code-tester-2.9.0-setup.exe" && exit
   ```

2. **刪除安裝檔**：
   ```bat
   del "%USERPROFILE%\Desktop\ntut-code-tester-2.9.0-setup.exe" && exit
   ```

3. **派送 `pre_settings.json` 設定檔**：
   請確認檔案內容中的 `remoteHost` 已指向伺服器真實 IP：
   ```json
   {
     "testTitle": "北科大計算機程式設計考試",
     "description": "測驗時間請遵從現場監考人員指示",
     "remoteHost": "http://192.168.1.100:3000"
   }
   ```
   將此檔案派送至學生桌面後，執行以下指令移動至程式資源目錄：
   ```bat
   move /Y "%USERPROFILE%\Desktop\pre_settings.json" "%LOCALAPPDATA%\Programs\ntut-code-tester\resources\pre_settings.json" && exit
   ```

4. **啟動學生端應用程式**：
   ```bat
   start "" "%LOCALAPPDATA%\Programs\ntut-code-tester\NTUTOnMachineTest.exe" && exit
   ```

5. **強制關閉學生端應用程式 (若有需要)**：
   ```bat
   taskkill /IM NTUTOnMachineTest.exe /F && exit
   ```

---

## 考試前自我測試

主系統部署完成後，請於瀏覽器進入管理後台：
- **網址**：`http://<SERVER_IP>:5173/judge`
- 切換至 **Deploy Test** 分頁：
  - 系統將會發送 probe 測試 Piston 的 C、C++、Python 實際編譯與運行狀態。
  - 驗證 CE、RE、TLE、MLE 等判定行為。
  - 檢視系統負載與並發佇列處理狀況。
