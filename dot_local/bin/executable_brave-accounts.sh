#!/bin/sh

brave-browser --new-window `jq '.roots.other.children[] | select(.name == "Accounts").children[].url' ~/.config/BraveSoftware/Brave-Browser/Default/Bookmarks | tr '\n' ' '| sed s/\"//g`
