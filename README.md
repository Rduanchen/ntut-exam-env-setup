# How to install and run NTUT Exam Environment

## Prerequisites

- Docker
- Docker Compose
- Git

## Steps to run

1. Clone the repository:

   ```bash
   git clone https://github.com/Rduanchen/ntut-exam-env-setup
   cd ntut-exam-env-setup
   ```

2. install

   ```bash
   sh ./install.sh
   ```

   windows user can run

   ```powershell
   .\install.ps1
   ```

3. Start the services using Docker Compose:

   ```bash
   docker-compose up -d
   ```

   linux user can run

   ```
   docker compose up -d
   ```

4. install python in piston

   ```bash
   sh ./install-piston.sh
   ```

   windows user can run

   ```powershell
   .\install-piston.ps1
   ```

## Reccomand Software to use

- VSCode
- Postman
- DBeaver
