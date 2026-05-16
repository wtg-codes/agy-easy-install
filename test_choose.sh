options=("Cancel" "Install" "Cleanup")
CHOICE=$(gum choose "${options[@]}")
echo "CHOICE: $CHOICE"
