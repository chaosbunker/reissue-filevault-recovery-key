#!/usr/bin/env bash
## Get the OS version
OS=`/usr/bin/sw_vers -productVersion | awk -F. {'print $2'}`

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# :path:to:icon.icns
ICON="${DIR//\//:}:appIcon.icns"

# display_message "Message" "button name" "window title"
function display_message() {
  osascript <<EOT
    tell app "System Events"
      display dialog "$1" buttons {"$2"} default button 1 with icon file "${ICON}" with title "${3}"
      return  -- Suppress result
    end tell
EOT
}

# get current user
CURRENT_USER=`/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }'`

while [[ -z $validPassword ]];do
	sudo -k
	# store password in variable
	password="$(osascript -e 'Tell application "System Events" to display dialog "Enter your password to reissue FileVault recovery key:" buttons {"Submit"}  default button 1 default answer "" with hidden answer' -e 'text returned of result' 2>/dev/null)"
	# validate password
	echo "$password" | sudo -Sv
	[[ $? == 1 ]] \
		&& display_message "Password is incorrect." "OK" "Error" \
		|| validPassword=1
done

# write new fileVault recovery key to /Users/Shared/fvkey.plist
# exit if OS is less than 10.13
if [[ $OS -ge 13 ]]; then
fvkeyplist=$(expect -d -c "
	log_user 0
	spawn sudo fdesetup changerecovery -personal -outputplist
	expect \"Password:\"
	send ${password}\n
	expect \"Enter the user name:\"
	send ${CURRENT_USER}\n
	send \r
	expect \"Enter the password for user '${CURRENT_USER}':\"
	send ${password}\n
	send \r
	log_user 1
	expect eof
	" > /Users/Shared/fvkey.plist)
else
	display_message "macOS 10.13 High Sierra required. Please upgrade your system." "OK" "Error"
	exit 1
fi



# read recovery key from fvkey.plist into variable and display it in dialog
[[ -f /Users/Shared/fvkey.plist ]] \
	&& (recoveryKey=$(cat /Users/Shared/fvkey.plist | sed -n '/RecoveryKey/{n;p;}' | awk -F'[>|<]' '{print $3}') \
	&& display_message "\n$recoveryKey" "I have written down my key" "Your FileVault Recovery Key") \
	|| display_message "\nFileVault key could not be set!" "OK" "Error"
