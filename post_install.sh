#!/bin/sh
set -eu

log() {
  echo "$1" >>/root/PLUGIN_INFO
}

plugin services set nginx syncthing

syncthing_user=syncthing
plugin config set syncthing_user "$syncthing_user"

plugin config set syncthing_nginx_mode http

mkdir -p /Sync
chmod -R 0750 /Sync
chown -R "$syncthing_user:$syncthing_user" /Sync
log "Created initial sync directory under /Sync"

if ! grep -q 'template render' /usr/local/etc/rc.d/nginx >/dev/null; then
  ex /usr/local/etc/rc.d/nginx <<EOEX
/^nginx_checkconfig()
+3
i


	nginx_mode="\$(/usr/local/bin/plugin config get syncthing_nginx_mode || echo '')"
	case "\$nginx_mode" in
		https|http)
			/usr/local/bin/plugin template render \\
				"/usr/local/share/syncthing/nginx/nginx.conf.\${nginx_mode}.in" \\
				/usr/local/etc/nginx/nginx.conf || return 1
			;;
		*)
			echo "nginx_mode could not be determined; syncthing_nginx_mode=\$nginx_mode" >&2
			return 1
			;;
	esac
.
wq!
EOEX
  log "Modified nginx rc.d script to render config"
fi

sysrc -f /etc/rc.conf nginx_enable=YES
log "Enabled nginx service"

# Enable the services
sysrc -f /etc/rc.conf syncthing_enable=YES
log "Enabled syncthing service"

# Start the services
service nginx start
log "Started nginx service"

service syncthing start
log "Started syncthing service"
