# 📘 DB Labs

Репозиторий предназначен для **выполнения лабораторных работ по базам данных**.
Каждая лабораторная работа изолирована в своей папке и имеет **собственную базу данных**, чтобы не мешать остальным.

## ⚙️ Настройка и запуск

### 🔐 Настройки окружения
Файл .env (в корне проекта):
```dotenv
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=labuser
POSTGRES_PASSWORD=labpass
POSTGRES_DB=postgres
```

### 🚀Запуск Docker:
```bash
docker compose up -d
```
Создаст и запустит контейнер с PostgreSQL (порт 5432 по умолчанию).

## Main Scripts

### 1. Запуск прогон Миграций
```bash
python3 scripts/run_lab.py <lab00>
```

### 2. Пересоздать базу (удалить и заново)
```bash
python3 scripts/run_lab.py <lab00> --recreate
```

### 3. Выполнить конкретный SQL-файл
```bash
python3 scripts/run_lab.py <lab00> -f labs/<lab00>/sql/<migration_file.sql>
```

### 4. Передать переменные в SQL
```bash
python3 scripts/run_lab.py <lab00> --vars SCHEMA=lab01 TZ=UTC ...
```

## 🧩 Где искать результаты
После выполнения скрипта в PostgreSQL создаётся отдельная база:
	• <lab00> → <lab00>_db

Для перезода в бд:
```bash
psql -h localhost -p 5432 -U labuser -d <lab00>_db
```