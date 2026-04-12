#!/bin/sh
cosmic-launcher &

# Wait until cosmic-launcher process is ready by checking if it owns the DBus name
for i in $(seq 1 20); do
    sleep 0.1
    if gdbus call --session \
        --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner \
        "com.system76.CosmicLauncher" 2>/dev/null | grep -q "true"; then
        break
    fi
done

# Extra small delay for focus to settle after DBus is ready
sleep 0.1
ydotool type --key-delay 10 "ssh "
