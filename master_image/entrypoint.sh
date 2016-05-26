#!/bin/bash
set -e

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

if [ "$1" = 'mysqld' ]; then
	# Get config
	DATADIR="$("$@" --verbose --help --log-bin-index=/tmp/tmp.index 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and password option is not specified '
			echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
			exit 1
		fi

		if [ -z "$MYSQL_REPLICATION_PASSWORD" ]; then
                        echo >&2 'error: database is uninitialized and MYSQL_REPLICATION_PASSWORD not set'
                        echo >&2 '  Did you forget to add -e MYSQL_REPLICATION_PASSWORD=... ?'
                        exit 1
                fi

		# If the password variable is a filename we use the contents of the file
		if [ -f "$MYSQL_ROOT_PASSWORD" ]; then
			MYSQL_ROOT_PASSWORD="$(cat $MYSQL_ROOT_PASSWORD)"
		fi
		mkdir -p "$DATADIR"
		chown -R mysql:mysql "$DATADIR"
#		mkdir /var/lib/mysql/data
#		chown mysql:mysql /var/lib/mysql/data
		mkdir /etc/mysql/conf.d
		chown mysql:mysql /etc/mysql/conf.d
		mkdir /var/log/mysql
		chown mysql:mysql /var/log/mysql	
		sed "s/SERVER_ID/${RANDOM}/g" /tmp/my.cnf.tmpl > /etc/mysql/my.cnf
		
		echo 'Initializing database'
		mysql_install_db --basedir=/usr --user=mysql --datadir="$DATADIR"
		echo 'Database initialized'
        
        mkdir /run/mysqld
        chown mysql:mysql /run/mysqld
		mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
		pid="$!"

		mysql=( mysql --protocol=socket -uroot )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		mysql_tzinfo_to_sql /usr/share/zoneinfo | "${mysql[@]}" mysql
		
		if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			MYSQL_ROOT_PASSWORD="$(pwmake 128)"
			echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
		fi
		"${mysql[@]}" <<-EOSQL
			DELETE FROM mysql.user where user != 'mysql.sys';
			CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
			DROP DATABASE IF EXISTS test ;
            FLUSH PRIVILEGES ;
		EOSQL
		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi

		if [ "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
			mysql+=( "$MYSQL_DATABASE" )
		fi

		if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
			echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" | "${mysql[@]}"

			if [ "$MYSQL_DATABASE" ]; then
				echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;" | "${mysql[@]}"
			fi

			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi
		#echo "GRANT REPLICATION SLAVE, REPLICATION CLIENT on *.* TO 'repl'@'10.100.%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"  | "${mysql[@]}"
		echo "GRANT REPLICATION SLAVE, REPLICATION CLIENT on *.* TO 'repl'@'10.%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"  | "${mysql[@]}"
		echo "GRANT REPLICATION SLAVE, REPLICATION CLIENT on *.* TO 'repl'@'172.17.%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"  | "${mysql[@]}"
		echo "GRANT REPLICATION SLAVE, REPLICATION CLIENT on *.* TO 'repl'@'172.18.%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"  | "${mysql[@]}"
		echo 'FLUSH PRIVILEGES ;'  | "${mysql[@]}"
		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)  echo "$0: running $f"; . "$f" ;;
				*.sql) echo "$0: running $f"; "${mysql[@]}" < "$f" && echo ;;
				*)     echo "$0: ignoring $f" ;;
			esac
			echo
		done

		if [ ! -z "$MYSQL_ONETIME_PASSWORD" ]; then
			"${mysql[@]}" <<-EOSQL
				ALTER USER 'root'@'%' PASSWORD EXPIRE;
			EOSQL
		fi
		if ! kill -s TERM "$pid" || ! wait "$pid"; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		echo
		echo 'MySQL init process done. Ready for start up.'
		echo
	fi

	chown -R mysql:mysql "$DATADIR"
fi

exec mysqld --user=mysql --datadir="$DATADIR"



