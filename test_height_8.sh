sed -i 's/CHOICE=$(gum filter --height=[0-9]* /CHOICE=$(gum filter --height=8 /' src/40_ui.sh
./build.sh
python3 tests/test_ui_navigation.py 2>&1 | grep banner
