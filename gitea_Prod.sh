

CREATE USER 'gitea_db_user'@'localhost'
IDENTIFIED BY '$h0p!fy@b$2En0P2()O7';

GRANT CREATE, DROP
ON *.*
TO 'gitea_db_user'@'localhost';

GRANT SELECT, INSERT, UPDATE, DELETE
ON *.*
TO 'gitea_db_user'@'localhost'
WITH GRANT OPTION;


mysql -u gitea_db_user -p



test-git.nop-station.site
3565

127.0.0.1
3306
gitea_prod
gitea_db_user
$h0p!fy@b$2En0P2()O7




git.nop-station.com
3585







# Create separate directories for prod and prod
sudo mkdir -p /var/lib/gitea-prod/{custom,data,log}
sudo mkdir -p /etc/gitea-prod
sudo mkdir -p /var/run/gitea-prod


# Set permissions
sudo chown -R www-data:www-data /var/lib/gitea-prod /etc/gitea-prod /var/run/gitea-prod

sudo chmod 750 /etc/gitea-prod 


sudo nano /etc/gitea-prod/app.ini



sudo chown www-data:www-data /etc/gitea-prod/app.ini
sudo chmod 600 /etc/gitea-prod/app.ini

sudo nano /etc/systemd/system/gitea-prod.service



# *************************** Service file ***************************
[Unit]
Description=Gitea prod
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/lib/gitea-prod
ExecStart=/usr/local/bin/gitea web --config /etc/gitea-prod/app.ini
Restart=always
RestartSec=10
Environment=USER=gitea-prod HOME=/var/lib/gitea-prod GITEA_WORK_DIR=/var/lib/gitea-prod

[Install]
WantedBy=multi-user.target





sudo systemctl daemon-reload
sudo systemctl enable gitea-prod
sudo systemctl start gitea-prod

# Check status
sudo systemctl status gitea-prod


sudo journalctl -efu gitea-prod



sudo systemctl daemon-reload
sudo systemctl restart gitea-prod
