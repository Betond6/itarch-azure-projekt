# IT-architektúra csoportprojekt 2026 – Azure VM-ek, hálózati kommunikáció és konténerek

**Csapat:** [CSAPATNÉV] · **Tagok:** [Név 1] (infrastruktúra), [Név 2] (alkalmazás, tesztelés, videó)
**Videó:** [link] · **Műszaki dokumentáció:** [link / PDF a beadásban]

## Összefoglaló

Két Ubuntu 24.04 virtuális gép két külön Azure virtuális hálózatban (VNet), VNet peeringgel összekötve.
A **vm-app** gépen Docker Compose három konténert futtat (Nginx webszerver, FastAPI REST API, PostgreSQL adatbázis),
amelyeket a **vm-client** gép privát IP-címen ér el. A vm-app-nak nincs publikus IP-je, kívülről csak a
vm-client-en (jump host) keresztül érhető el. A hozzáférést NSG-szabályok és UFW tűzfal korlátozza.

```
 Csapattag ──SSH:22──► vm-client (10.10.1.4) ══ VNet peering ══► vm-app (10.20.1.4)
                       vnet-a 10.10.0.0/16                       vnet-b 10.20.0.0/16
                                                                 ├─ web  (Nginx)      :80
                                                                 ├─ api  (FastAPI)    :8000
                                                                 └─ db   (PostgreSQL) :5432
```

| Gép | VNet / alhálózat | Privát IP | Publikus IP | Méret |
|---|---|---|---|---|
| vm-client | vnet-a 10.10.0.0/16 / snet-client 10.10.1.0/24 | 10.10.1.4 | van (SSH csak a csapat IP-iről) | Standard_B1s |
| vm-app | vnet-b 10.20.0.0/16 / snet-app 10.20.1.0/24 | 10.20.1.4 | nincs | Standard_B2s |

## Alkalmazott technológiák

- **Azure:** Virtual Machines, Virtual Network, VNet peering, Network Security Group, Network Watcher, cloud-init
- **Operációs rendszer:** Ubuntu Server 24.04 LTS, UFW tűzfal
- **Konténerek:** Docker Engine, Docker Compose
- **Szolgáltatások:** Nginx 1.27, FastAPI (Python 3.12), PostgreSQL 16
- **Verziókezelés:** GitHub

## Kommunikációs forgatókönyvek

| # | Forgatókönyv | Forrás → cél | Port | Konténer |
|---|---|---|---|---|
| F1 | SSH (jump hoston át) | csapattag → vm-client → vm-app | 22 | – |
| F2 | HTTP weboldal | vm-client → vm-app | 80 | Nginx |
| F3 | REST API hívás | vm-client → vm-app | 8000, 80/api | FastAPI |
| F4 | Adatbázis-elérés | vm-client → vm-app | 5432 | PostgreSQL |
| F5 | Fájlátvitel (scp) | vm-client → vm-app | 22 | – |

## A repó tartalma

| Útvonal | Leírás |
|---|---|
| `docker-compose.yml` | A három konténer leírása (portok, volume, healthcheck, újraindítás) |
| `api/` | A REST API forrása (`main.py`) és `Dockerfile`-ja |
| `db/init.sql` | Adatbázis-séma és kezdő adatok |
| `web/` | Statikus weboldal és Nginx konfiguráció (reverse proxy a `/api/` útvonalra) |
| `cloud-init/vm-app.yaml` | A vm-app első indításakor lefutó telepítés (Docker, repó, konténerek, UFW) |
| `cloud-init/vm-client.yaml` | A vm-client első indításakor lefutó telepítés (teszteszközök, UFW) |
| `scripts/test.sh` | Reprodukálható tesztek F1–F5-re és negatív tesztek |

## Telepítés

Az infrastruktúra az Azure Portalon jön létre, a részletes lépések a projekt elkészítési útmutatójában vannak.
Röviden:

1. Ennek a repónak a forkolása/feltöltése, a `cloud-init/*.yaml` fájlokban a `GITHUB_FELHASZNALO` átírása.
2. Erőforráscsoport (`rg-itarch-projekt`), két VNet, két NSG (szabályok: lásd a dokumentációt), VNet peering.
3. vm-app létrehozása ideiglenes publikus IP-vel; *Advanced → Custom data*: `cloud-init/vm-app.yaml` tartalma.
4. vm-client létrehozása; *Custom data*: `cloud-init/vm-client.yaml` tartalma.
5. Statikus privát IP-k beállítása, majd a vm-app publikus IP-jének eltávolítása.

## Tesztelés (reprodukálható lépések)

1. Belépés a vm-client gépre: `ssh -i itarch-key.pem azureuser@<vm-client publikus IP>`
2. A vm-client kulcsának felvétele a vm-app-ra (Portal → vm-app → Reset password → Reset SSH public key, felhasználó: `vmclient`).
3. Az adatbázis jelszava a vm-app `/opt/projekt/.env` fájljában van (Portal → vm-app → Run command). **A repóba nem kerül be.**
4. Futtatás a vm-client-en:

```bash
cd ~/projekt
export DB_PASSWORD='<jelszó>'
./scripts/test.sh | tee teszt-eredmeny.log
```

**Várt eredmény:** F1 – a vm-app hostneve és a három futó konténer; F2 – `HTTP 200`; F3 – `{"status":"ok"}` és JSON lista;
F4 – sorok száma az `items` táblában; F5 – egyező SHA-256 hash a két oldalon;
negatív tesztek – a 6379-es port nem elérhető, az nmap csak a 22, 80, 5432, 8000 portot mutatja nyitva.

Kiegészítő ellenőrzés az Azure Portalon: Network Watcher → *Connection troubleshoot* és *IP flow verify*.

## Biztonság röviden

- A vm-app-nak nincs publikus IP-je; az nsg-app csak a vm-client alhálózatából enged be (22, 80, 8000), az 5432-t csak a 10.10.1.4-ről.
- Kulcsalapú SSH, jelszavas belépés tiltva; SSH a vm-client-re csak a csapattagok IP-címéről.
- Titkok (adatbázis-jelszó, privát kulcs) nincsenek a repóban (`.gitignore`).

## Takarítás

- Szüneteltetés: Azure Portal → Virtual machines → **Stop**.
- Végleges törlés: Azure Portal → Resource groups → `rg-itarch-projekt` → **Delete resource group**.
