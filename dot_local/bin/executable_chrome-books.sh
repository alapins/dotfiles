#!/bin/sh

# Bookmarks moved to account storage are in AccountBookmarks; read both, drop dupes.
d=~/.config/google-chrome/Default
google-chrome --new-window `cat $d/AccountBookmarks $d/Bookmarks 2>/dev/null | jq '.roots.other.children[] | select(.name == "Books Downloads").children[].url' | awk '!seen[$0]++' | tr '\n' ' ' | sed s/\"//g`
