---
Odoo-18-bash-script
---

Инструкция установки

**1. Запустить VPS**

Рекомендация минимум
* 2 Core
* 3 RAM
* 20 GB SSD

**2. Подключитесь к хостингу и запустить консоль**

Рекомендация
* `WinSCP + Putty`

**3. Загрузить скрипт**
``` bash
wget https://raw.githubusercontent.com/6Ministers/Odoo-18-bash-script/refs/heads/master/install_odoo18_ubuntu.sh
```

**4. Конфигурация скрипта**

Замените WEBSITE_NAME на ваш домен в WinSCP клиенте

* `WEBSITE_NAME="WEBSITE_NAME"  # Set the domain name`
* `ADMIN_EMAIL="admin@WEBSITE_NAME"  # Email for SSL registration`

Установите на свое усмотрение `True` или `False`
* `INSTALL_NGINX="True"  # Set to True if you want to install Nginx`
* `ENABLE_SSL="True"  # Enable SSL`

**5. Активировать скрипт**
``` bash
sudo chmod +x install_odoo18_ubuntu.sh
```

**6. Запустить скрипт**
``` bash
./install_odoo18_ubuntu.sh
```

**7. Подождите 5-8 минут**

**8. Перейдите по ссылке:**

`https://Ваш_домен/`

**9.Запустите вашу базу данных**

Master Password находится в файле:

`​/etc/odoo18.conf`
