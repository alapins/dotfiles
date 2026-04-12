#!/bin/sh

google-chrome --new-window `jq '.roots.other.children[] | select(.name == "Servus Maintenance").children[].url' ~/.config/google-chrome/Default/Bookmarks | tr '\n' ' ' | sed s/\"//g`
