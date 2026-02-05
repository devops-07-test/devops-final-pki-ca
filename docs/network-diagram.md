```markdown
# Сетевая схема инфраструктуры

## VPC: 10.10.0.0/24

| Узел | IP пример | Назначение |
|------|----------|------------|
vm-ca | 10.10.0.10 | PKI
vm-vpn | 10.10.0.20 | Gateway
vm-monitor | 10.10.0.30 | Metrics
vm-backup | 10.10.0.40 | Storage

---

## Потоки трафика

Internet
   │
   │ UDP 1194
   ▼
vm-vpn
   │
   ├────────► vm-ca (CSR / Cert validation)
   ├────────► vm-monitor (metrics scrape)
   └────────► vm-backup (archive)

vm-monitor
   ├──► vm-ca
   ├──► vm-vpn
   └──► vm-backup

vm-backup
   ◄── pulls configs from all nodes

---

## Открытые порты

### vm-ca
22

### vm-vpn
22  
1194/udp

### vm-monitor
22  
9090  
9093  

### vm-backup
22

---

## Подсеть VPN клиентов

10.8.0.0/24

Маршрут:

Client → VPN → Internal 10.10.0.0/24
