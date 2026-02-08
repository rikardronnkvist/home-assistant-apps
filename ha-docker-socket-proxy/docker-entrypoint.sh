#!/bin/sh
set -e

# Raise default nofile limit for HAProxy v3
ulimit -n 10000 2>/dev/null || true

# Helper function to extract JSON values without jq
get_json_value() {
    local key="$1"
    local default="$2"
    local file="$3"
    
    # Extract value for the key, handling both string and numeric values
    value=$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" "$file" | sed 's/.*:[[:space:]]*//' | sed 's/\"//g' | tr -d ' ')
    
    # Return default if empty
    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Load configuration from Home Assistant if running as add-on
if [ -f /data/options.json ]; then
    # Export all options from Home Assistant config as environment variables
    export ALLOW_RESTARTS=$(get_json_value "ALLOW_RESTARTS" "false" "/data/options.json")
    export ALLOW_STOP=$(get_json_value "ALLOW_STOP" "false" "/data/options.json")
    export ALLOW_START=$(get_json_value "ALLOW_START" "false" "/data/options.json")
    export AUTH=$(get_json_value "AUTH" "false" "/data/options.json")
    export BUILD=$(get_json_value "BUILD" "true" "/data/options.json")
    export COMMIT=$(get_json_value "COMMIT" "true" "/data/options.json")
    export CONFIGS=$(get_json_value "CONFIGS" "true" "/data/options.json")
    export CONTAINERS=$(get_json_value "CONTAINERS" "true" "/data/options.json")
    export DISABLE_IPV6=$(get_json_value "DISABLE_IPV6" "false" "/data/options.json")
    export DISTRIBUTION=$(get_json_value "DISTRIBUTION" "true" "/data/options.json")
    export EVENTS=$(get_json_value "EVENTS" "true" "/data/options.json")
    export EXEC=$(get_json_value "EXEC" "false" "/data/options.json")
    export GRPC=$(get_json_value "GRPC" "false" "/data/options.json")
    export IMAGES=$(get_json_value "IMAGES" "true" "/data/options.json")
    export INFO=$(get_json_value "INFO" "true" "/data/options.json")
    export LOG_LEVEL=$(get_json_value "LOG_LEVEL" "info" "/data/options.json")
    export NETWORKS=$(get_json_value "NETWORKS" "true" "/data/options.json")
    export NODES=$(get_json_value "NODES" "true" "/data/options.json")
    export PING=$(get_json_value "PING" "true" "/data/options.json")
    export PLUGINS=$(get_json_value "PLUGINS" "true" "/data/options.json")
    export POST=$(get_json_value "POST" "false" "/data/options.json")
    export SECRETS=$(get_json_value "SECRETS" "false" "/data/options.json")
    export SERVICES=$(get_json_value "SERVICES" "true" "/data/options.json")
    export SESSION=$(get_json_value "SESSION" "true" "/data/options.json")
    export SOCKET_PATH=$(get_json_value "SOCKET_PATH" "/var/run/docker.sock" "/data/options.json")
    export SWARM=$(get_json_value "SWARM" "true" "/data/options.json")
    export SYSTEM=$(get_json_value "SYSTEM" "true" "/data/options.json")
    export TASKS=$(get_json_value "TASKS" "false" "/data/options.json")
    export VERSION=$(get_json_value "VERSION" "true" "/data/options.json")
    export VOLUMES=$(get_json_value "VOLUMES" "true" "/data/options.json")
fi

# Normalize the input for DISABLE_IPV6 to lowercase
DISABLE_IPV6_LOWER=$(echo "$DISABLE_IPV6" | tr '[:upper:]' '[:lower:]')

# Check for different representations of 'true' and set BIND_CONFIG
case "$DISABLE_IPV6_LOWER" in
    1|true|yes)
        BIND_CONFIG=":2375"
        ;;
    *)
        BIND_CONFIG="[::]:2375 v4v6"
        ;;
esac

# Process the HAProxy configuration template using sed
sed "s/\${BIND_CONFIG}/$BIND_CONFIG/g" /usr/local/etc/haproxy/haproxy.cfg.template > /tmp/haproxy.cfg

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ "$1" = 'haproxy' ]; then
	shift # "haproxy"
	# if the user wants "haproxy", let's add a couple useful flags
	#   -W  -- "master-worker mode" (similar to the old "haproxy-systemd-wrapper"; allows for reload via "SIGUSR2")
	#   -db -- disables background mode
	set -- haproxy -W -db "$@"
fi

exec "$@"
