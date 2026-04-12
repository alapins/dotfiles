#!/bin/sh

get_hosts() {
    grep -i "^Host " ~/.ssh/config \
        | awk '{print $2}' \
        | grep -v '\*'
}

emit_results() {
    query="$1"
    # Strip leading "ssh " prefix if present so we filter by hostname only
    query=$(printf '%s' "$query" | sed 's/^ssh //')
    
    hosts=$(get_hosts)
    id=0
    for host in $hosts; do
        if [ -z "$query" ] || printf '%s' "$host" | grep -qi "$query"; then
            printf '{"Append":{"id":%d,"name":"SSH: %s","description":"Connect to %s","keywords":["ssh","%s"],"icon":{"Name":"network-server"}}}\n' \
                "$id" "$host" "$host" "$host"
        fi
        id=$((id + 1))
    done
    printf '"Finished"\n'
}

launch_terminal() {
    host="$1"
    # Log for debugging
    echo "Launching terminal for $host" >> /tmp/ssh-plugin.log
    
    if command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec ssh "$host" >/dev/null 2>&1 &
    elif command -v ghostty >/dev/null 2>&1; then
        nohup ghostty -e ssh "$host" >/dev/null 2>&1 &
    elif command -v cosmic-terminal >/dev/null 2>&1; then
        nohup cosmic-terminal --command "ssh $host" >/dev/null 2>&1 &
    fi
    
    echo "Launch attempted" >> /tmp/ssh-plugin.log
}

while IFS= read -r line; do
    echo "received: $line" >> /tmp/ssh-plugin.log
    if printf '%s' "$line" | grep -q '"Search"'; then
        query=$(printf '%s' "$line" | grep -o '"Search":"[^"]*"' | cut -d'"' -f4)
        emit_results "$query"

    elif printf '%s' "$line" | grep -q '"Activate"'; then
        id=$(printf '%s' "$line" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
        host=$(get_hosts | sed -n "$((id + 1))p")
        echo "Got activate for id=$id host=$host" >> /tmp/ssh-plugin.log
        launch_terminal "$host"
        printf '"Close"\n'

    elif printf '%s' "$line" | grep -q '"Exit"'; then
        exit 0
    fi
done
