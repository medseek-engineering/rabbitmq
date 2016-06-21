#!/bin/bash
set -e

if [ "$RABBITMQ_ERLANG_COOKIE" ]; then
	cookieFile='/var/lib/rabbitmq/.erlang.cookie'
	if [ -e "$cookieFile" ]; then
		if [ "$(cat "$cookieFile" 2>/dev/null)" != "$RABBITMQ_ERLANG_COOKIE" ]; then
			echo >&2
			echo >&2 "warning: $cookieFile contents do not match RABBITMQ_ERLANG_COOKIE"
			echo >&2
		fi
	else
		echo "$RABBITMQ_ERLANG_COOKIE" > "$cookieFile"
		chmod 600 "$cookieFile"
		chown rabbitmq "$cookieFile"
	fi
fi

if [ "$1" = 'rabbitmq-server' ]; then
	configs=(
		# https://www.rabbitmq.com/configure.html
		default_vhost
		default_user
		default_pass
	)

	haveConfig=
	for conf in "${configs[@]}"; do
		var="RABBITMQ_${conf^^}"
		val="${!var}"
		if [ "$val" ]; then
			haveConfig=1
			break
		fi
	done

	if [ "$haveConfig" ]; then
		cat > /etc/rabbitmq/rabbitmq.config <<-'EOH'
			[
			  {rabbit,
			    [
		EOH
		for conf in "${configs[@]}"; do
			var="RABBITMQ_${conf^^}"
			val="${!var}"
			[ "$val" ] || continue
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOC
			      {$conf, <<"$val">>},
			EOC
		done
		cat >> /etc/rabbitmq/rabbitmq.config <<-'EOF'
			      {loopback_users, []}
			    ]
			  }
			].
		EOF
	fi

	( sleep 10 ; \
        # Create predict vhost
	rabbitmqctl add_vhost predict ; \
        # Create Rabbitmq user
	rabbitmqctl add_user rabbitmq rabbitmq ; \
        # Set administrator user tag
	rabbitmqctl set_user_tags rabbitmq administrator ; \
        # Provide access to predict vhost
	rabbitmqctl set_permissions -p predict rabbitmq ".*" ".*" ".*" ; \
        # Provide access to / vhost
	rabbitmqctl set_permissions -p / rabbitmq ".*" ".*" ".*" ; ) &
		# Create medseek-api exchange
	rabbitmqadmin declare exchange name=medseek-api type=topic durable=true
	
	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"
fi

exec "$@"
