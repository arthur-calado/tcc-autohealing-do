#cloud-config
package_update: true
package_upgrade: true
packages:
  - docker.io
write_files:
  - path: /opt/db/init.sql
    permissions: '0644'
    content: |
      CREATE USER tcc WITH PASSWORD 'tccpass';
      CREATE DATABASE tccdb OWNER tcc;
      GRANT ALL PRIVILEGES ON DATABASE tccdb TO tcc;
  - path: /etc/systemd/system/tcc-postgres.service
    permissions: '0644'
    content: |
      [Unit]
      Description=PostgreSQL via Docker
      After=docker.service
      Requires=docker.service

      [Service]
      Restart=always
      RestartSec=3
      ExecStartPre=/usr/bin/mkdir -p /opt/pgdata
      ExecStart=/usr/bin/docker run --rm --name tcc-postgres -p 5432:5432 \
        -e POSTGRES_PASSWORD=supersecret \
        -e POSTGRES_DB=postgres \
        -e POSTGRES_USER=postgres \
        -v /opt/pgdata:/var/lib/postgresql/data \
        -v /opt/db/init.sql:/docker-entrypoint-initdb.d/init.sql \
        postgres:16
      ExecStop=/usr/bin/docker stop tcc-postgres

      [Install]
      WantedBy=multi-user.target

runcmd:
  - systemctl daemon-reload
  - systemctl enable --now docker
  - systemctl enable --now tcc-postgres
