#!/bin/bash
options=("Cancel" "Install" "Cleanup")
echo "HELLO BANNER"
CHOICE=$(gum filter --height 6 --no-limit --no-strict --indicator="❯ " --placeholder="Select an option..." "${options[@]}")
echo "Choice was: $CHOICE"
