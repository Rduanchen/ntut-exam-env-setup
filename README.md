# 北科大程式設計考試環境 (NTUT Exam Environment)

本專案為北科大程式設計考試系統的環境部署腳本。提供互動式的自動化腳本，能協助您快速完成專案下載、依賴安裝、系統部署及 Piston 程式碼執行環境設定。

## 系統需求 (Prerequisites)

- [Node.js](https://nodejs.org/) (若主系統不使用 Docker 部署則為必備)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (部署 Piston 評測機必備)
- **Git Bash** (Windows 使用者強烈建議，且需以**系統管理員身分**執行)
- 推薦使用工具：VSCode、Postman、DBeaver

---

## 快速自動化部署 (Quick Setup)

我們提供了一個全新的 `setup.sh` 互動式腳本，整合了所有的環境安裝流程。

### 部署步驟

1. **取得專案**：
   請在終端機 (Windows 用戶請將 Git Bash **以系統管理員身分執行**) 輸入以下指令：
   ```bash
   git clone https://github.com/Rduanchen/ntut-exam-env-setup
   cd ntut-exam-env-setup
   ```

2. **執行安裝腳本**：
   ```bash
   bash setup.sh
   ```

3. **依據互動提示完成設定**：
   - **Port 設定**：自訂後端 API 與前端網站的 Port（預設為 3000 及 5173）。
   - **主系統部署方式**：選擇是否使用 Docker 或是在本地 Node 環境下背景啟動 (支援自動安裝 pm2)。
   - **Windows 防火牆**：腳本會自動利用 `netsh` 開放指定 Port 給區域網路連線。
   - **Piston 部署**：自動 Clone 專案、注入資源限制變數 (`PISTON_RUN_TIMEOUT` 等)，並使用 Docker 啟動。
   - **語言環境安裝**：系統啟動後，腳本會在最後詢問您是否要透過 `ppman` 自動安裝 GCC (C/C++) 或 Python 的編譯環境（由於安裝時間較長，已移至最後階段進行）。

---

## 服務管理 (使用 PM2)

若您在部署過程中選擇使用 `pm2` 來於背景運行後端及前端服務，可使用以下常用指令管理：

- **查看運行中服務**：`pm2 list`
- **查看即時日誌**：`pm2 logs`
- **重啟指定服務**：`pm2 restart ntut-backend` 或 `pm2 restart ntut-frontend`
- **停止所有服務**：`pm2 stop all`
- **刪除所有服務**：`pm2 delete all`

---

## 遠端控制腳本 (Remote Control Script)

如果您在教室內有電腦教室管理系統 (如廣播軟體)，可以利用以下腳本來遠端控制學生電腦上的考試環境。

1. **在學生電腦上安裝應用程式**：
   - 將 `.exe` 安裝檔放到學生電腦的桌面上。
   - 執行以下指令 (請依據實際檔名修改 `ntut-code-tester-1.6.5-setup.exe`)：
     ```bat
     "%USERPROFILE%\Desktop\ntut-code-tester-1.6.5-setup.exe" && exit
     ```

2. **移除安裝檔**：
   - 執行以下指令刪除桌面上的安裝檔：
     ```bat
     del "%USERPROFILE%\Desktop\ntut-code-tester-1.6.5-setup.exe" && exit
     ```

3. **設定 `pre-settings.json` (提前組態設定)**：
   - 建立一個 `pre-settings.json` 檔案，內容如下 (請務必將 `remoteHost` 改為您伺服器的 IP)：
     ```json
     {
       "testTitle": "北科大計算機程式設計期中考",
       "description": "測驗時間為 18:00 至 20:00",
       "publicKey": "key-here",
       "remoteHost": "http://140.124.184.90:3000"
     }
     ```
   - 將此檔案派送到學生電腦的桌面。
   - 利用以下指令將檔案移動到應用程式的資源目錄中：
     ```bat
     move /Y "%USERPROFILE%\Desktop\pre-settings.json" "%APPDATA%\Local\Programs\ntut-code-tester\resources\pre-settings.json" && exit
     ```

4. **啟動學生端應用程式**：
   - 執行以下指令：
     ```bat
     start "" "%LOCALAPPDATA%\Programs\ntut-code-tester\NTUTOnMachineTest" && exit
     ```

5. **強制關閉學生端應用程式 (若有需要)**：
   - 執行以下指令：
     ```bat
     taskkill /IM NTUTOnMachineTest.exe /F && exit
     ```
