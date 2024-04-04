#!/bin/bash

USER_ID=${LOCAL_USER_ID:-1000}

if [ "${1#-}" != "$1" ]; then
	set -- FreeKill -s "$@"
fi

if [ "$1" = 'FreeKill' -a "$(id -u)" = '0' ]; then
	id -u freekill >&/dev/null
	if [ $? -ne 0 ]; then
		useradd --shell /bin/bash -u $USER_ID -o -c "" -m freekill
		usermod -aG root freekill
		export HOME=/home/freekill
		mkdir -p $HOME/.local/share
		ln -s /data $HOME/.local/share/FreeKill
		chown -R freekill:freekill $HOME
		if [ ! -d "/data/server" ]; then
			cp -r /usr/local/share/FreeKill/server /data
		fi
		if [ ! -d "/data/packages" ]; then
			cp -r /usr/local/share/FreeKill/packages /data
		fi
	fi
	chown -R freekill /data
	exec gosu freekill "$0" "$@"
fi

exec "$@"
