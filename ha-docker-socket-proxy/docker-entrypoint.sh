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

# Helper function to convert boolean values to integers (1 or 0)
convert_bool_to_int() {
    local value="$1"
    case "$(echo "$value" | tr '[:upper:]' '[:lower:]')" in
        true|1|yes)
            echo "1"
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Load configuration from Home Assistant if running as add-on
if [ -f /data/options.json ]; then
    # Export all options from Home Assistant config as environment variables
    export ALLOW_RESTARTS=$(convert_bool_to_int "$(get_json_value "ALLOW_RESTARTS" "false" "/data/options.json")")
    export ALLOW_STOP=$(convert_bool_to_int "$(get_json_value "ALLOW_STOP" "false" "/data/options.json")")
    export ALLOW_START=$(convert_bool_to_int "$(get_json_value "ALLOW_START" "false" "/data/options.json")")
    export AUTH=$(convert_bool_to_int "$(get_json_value "AUTH" "false" "/data/options.json")")
    export BUILD=$(convert_bool_to_int "$(get_json_value "BUILD" "true" "/data/options.json")")
    export COMMIT=$(convert_bool_to_int "$(get_json_value "COMMIT" "true" "/data/options.json")")
    export CONFIGS=$(convert_bool_to_int "$(get_json_value "CONFIGS" "true" "/data/options.json")")
    export CONTAINERS=$(convert_bool_to_int "$(get_json_value "CONTAINERS" "true" "/data/options.json")")
    export DISABLE_IPV6=$(convert_bool_to_int "$(get_json_value "DISABLE_IPV6" "false" "/data/options.json")")
    export DISTRIBUTION=$(convert_bool_to_int "$(get_json_value "DISTRIBUTION" "true" "/data/options.json")")
    export EVENTS=$(convert_bool_to_int "$(get_json_value "EVENTS" "true" "/data/options.json")")
    export EXEC=$(convert_bool_to_int "$(get_json_value "EXEC" "false" "/data/options.json")")
    export GRPC=$(convert_bool_to_int "$(get_json_value "GRPC" "false" "/data/options.json")")
    export IMAGES=$(convert_bool_to_int "$(get_json_value "IMAGES" "true" "/data/options.json")")
    export INFO=$(convert_bool_to_int "$(get_json_value "INFO" "true" "/data/options.json")")
    export LOG_LEVEL=$(get_json_value "LOG_LEVEL" "info" "/data/options.json")
    export NETWORKS=$(convert_bool_to_int "$(get_json_value "NETWORKS" "true" "/data/options.json")")
    export NODES=$(convert_bool_to_int "$(get_json_value "NODES" "true" "/data/options.json")")
    export PING=$(convert_bool_to_int "$(get_json_value "PING" "true" "/data/options.json")")
    export PLUGINS=$(convert_bool_to_int "$(get_json_value "PLUGINS" "true" "/data/options.json")")
    export POST=$(convert_bool_to_int "$(get_json_value "POST" "false" "/data/options.json")")
    export SECRETS=$(convert_bool_to_int "$(get_json_value "SECRETS" "false" "/data/options.json")")
    export SERVICES=$(convert_bool_to_int "$(get_json_value "SERVICES" "true" "/data/options.json")")
    export SESSION=$(convert_bool_to_int "$(get_json_value "SESSION" "true" "/data/options.json")")
    export SOCKET_PATH=$(get_json_value "SOCKET_PATH" "/var/run/docker.sock" "/data/options.json")
    export SWARM=$(convert_bool_to_int "$(get_json_value "SWARM" "true" "/data/options.json")")
    export SYSTEM=$(convert_bool_to_int "$(get_json_value "SYSTEM" "true" "/data/options.json")")
    export TASKS=$(convert_bool_to_int "$(get_json_value "TASKS" "false" "/data/options.json")")
    export VERSION=$(convert_bool_to_int "$(get_json_value "VERSION" "true" "/data/options.json")")
    export VOLUMES=$(convert_bool_to_int "$(get_json_value "VOLUMES" "true" "/data/options.json")")
fi

# Check DISABLE_IPV6 value and set BIND_CONFIG
case "$DISABLE_IPV6" in
    1|true)
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
