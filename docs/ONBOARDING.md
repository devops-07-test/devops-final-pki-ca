# Быстрый запуск проекта (5 минут)

Этот документ позволяет быстро развернуть инфраструктуру проекта.

---

## Требования

- Yandex Cloud аккаунт
- 4 VM Ubuntu 24.04
- SSH доступ

vm-ca  
vm-vpn  
vm-monitor  
vm-backup  

---

## Шаг 1 — Клонировать репозиторий

На локальной машине

git clone https://github.com/devops-07-test/devops-final-pki-ca.git

---

## Шаг 2 — Развернуть CA

scp repo + deb → vm-ca

На vm-ca:

sudo apt update  
sudo dpkg -i devops-ca-tools*.deb  

cd scripts  
sudo ./bootstrap.sh stage1

✔ Root CA создан

---

## Шаг 3 — Развернуть VPN

scp repo → vm-vpn

sudo ./bootstrap.sh stage2  
sudo stage2_request_server_csr.sh  

Подписать CSR на vm-ca

sudo sign_csr.sh server file.csr

Вернуть сертификаты

sudo stage2_fetch_signed_cert.sh vpn-server  
sudo stage2_configure_openvpn.sh  

sudo ./bootstrap.sh stage2-verify

✔ VPN работает

---

## Шаг 4 — Мониторинг

scp repo → vm-monitor

sudo ./bootstrap.sh stage3  
sudo ./bootstrap.sh stage3-verify

✔ Метрики собираются

---

## Шаг 5 — Бэкапы

scp repo → vm-backup

sudo ./bootstrap.sh stage4  
sudo ./bootstrap.sh stage4-verify

✔ Бэкапы создаются

---

## Готово

Развёрнута инфраструктура:

- PKI
- VPN
- Monitoring
- Backup

Проект демонстрирует навыки автоматизации и проектирования DevOps среды.