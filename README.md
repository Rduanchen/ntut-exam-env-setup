# How to install and run NTUT Exam Environment

Table of Contents

- [Setup via Docker Compose](#setup-via-docker-compose)
  - [Prerequisites](#prerequisites)
  - [Steps to run](#steps-to-run)
  - [Reccomand Software to use](#reccomand-software-to-use)
- [Setup via Manual Installation](#setup-via-manual-installation)
  - [Prerequisites](#prerequisites-1)
  - [Steps to run](#steps-to-run-1)
  - [Reccomand Software to use](#reccomand-software-to-use-1)
- [Remote Control Script:](#remote-control-script)

# Setup via Docker Compose

## Prerequisites

- Docker
- Docker Compose
- Git
- Node.js

## Steps to run

0. For windows user:
   please use git bash to run the following commands, and make sure you have set up the environment variable for docker and docker compose.

1. Clone the repository:

   ```bash
   git clone https://github.com/Rduanchen/ntut-exam-env-setup
   cd ntut-exam-env-setup
   ```

2. Install dependencies:

   linux and mac user can run

   ```bash
   sh ./install.sh
   ```

3. Start the services using Docker Compose:  
   **Note** : if you need config piston server, please open /ntut-exam-env-setup/piston/docker-compose.yml and paste your own environment variables in the environment section of piston service before run the following command.

   linux user can run

   ```
   docker compose up -d
   ```

   windows and mac user can run

   ```bash
   docker-compose up -d
   ```

4. install python in piston

   ```bash
   sh ./piston.sh
   ```

5. Start the backend server：
   linux and mac user can run

   ```bash
   sh ./backend.sh
   ```

## Reccomand Software to use

- VSCode
- Postman
- DBeaver

# Setup via Manual Installation

> **Before you start**
> Piston server must be running at docker container. If your server cannot run piston service, you have to setup piston server on another server and change some scripts in backend to point to that server.

## Prerequisites

- Node.js
- PostgreSQL 16
- VScode
- Git
- A piston server running

## Steps to run

1. Install PostgreSQL and create a database for the backend.
   - Let postgresql listen on 5433 port.
   - Create a database named `mydatabase`.
   - Create a user with superuser privileges and set a password.
     - username: `myuser`
     - password: `mypassword`

2. Clone the repository:

   ```bash
   sh install.sh
   ```

   or for windows user

   ```powershell
   .\install.ps1
   ```

3. Change the piston route
   - Open `/ntut-exam-env-setup/backend/src/constants/piston.config.ts` file.
   - Change the url variable on line 10 to point to your piston server address.

4. Start the services server:
   - For linux and mac user run

   ```bash
   sh ./backend.sh
   sh ./frontend.sh
   ```

# Config Piston Judge Server

you can open /ntut-exam-env-setup/piston/docker-compose.yml file and paste the following variables in the environment section of piston service, then restart the docker container.

```yaml
environment:
  - PISTON_RUN_TIMEOUT=30000
  - PISTON_RUN_CPU_TIME=30000
  - PISTON_COMPILE_TIMEOUT=10000
  - PISTON_COMPILE_CPU_TIME=10000
  - PISTON_OUTPUT_MAX_SIZE=10240
  - PISTON_RUN_MEMORY_LIMIT=-1
  - PISTON_COMPILE_MEMORY_LIMIT=-1
```

## Reccomand Software to use

- VSCode
- Postman
- DBeaver

# Remote Control Script:

If you have a Computer Lab Management System in your classroom, you can use the following scripts to remotely start the exam environment on student computers.

1. Install the application on student computers:
   - put the exe file in student desktop.
   - run the following command:
     note: replace `ntut-code-tester-1.6.5-setup.exe` with the actual filename if it's different.

   ```bat
      "%USERPROFILE%\Desktop\ntut-code-tester-1.6.5-setup.exe" && exit
   ```

2. Remove the installer from student computers:
   - run the following command:

   ```bat
      del "%USERPROFILE%\Desktop\ntut-code-tester-1.6.5-setup.exe" && exit
   ```

3. Setup the `pre-settings.json` file to configure the application before starting it:
   - Create a `pre-settings.json` file with the following content, please change the remoteHost url before use:

   ```json
   {
     "testTitle": "北科大計算機程式設計期中考",
     "description": "the test will be start at 18:00 and end at 20:00",
     "publicKey": "key-here",
     "remoteHost": "http://140.124.184.90:3001"
   }
   ```

   - Upload the `pre-settings.json` file to student computers' desktop.

   - Put `pre-settings.json` file in to application's working directory.

   ```bat
      move /Y "%USERPROFILE%\Desktop\pre-settings.json" "%APPDATA%\Local\Programs\ntut-code-tester\resources\pre-settings.json" && exit
   ```

4. Start the application on student computers:
   - run the following command:

   ```bat
      start "" "%LOCALAPPDATA%\Programs\ntut-code-tester\NTUTOnMachineTest" && exit
   ```

5. If you would like to force close the application on student computers:
   - run the following command:

   ```bat
      taskkill /IM NTUTOnMachineTest.exe /F && exit
   ```
