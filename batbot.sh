#!/bin/bash

# BaTbot current version
VERSION="1.5.0"

# default token and chatid
# or run BaTbot with option: -t <token>
TELEGRAMTOKEN="-YOUR-BOT-TOKEN-HERE-";

# how many seconds between check for new messages
# or run Batbot with option: -c <seconds>
CHECKNEWMSG=2;

# Commands
# you have to use this exactly syntax: ["/mycommand"]='<system command>'
# please, don't forget to remove all example commands!
#
# Please, DON'T allow bash escapes in botcommand regex
# it could expose your bot to RCE vulnerability.

declare -A botcommands
botcommands=(

	["/start"]='echo "Hi @FIRSTNAME, pleased to meet you :)"'

	["/myid"]='echo Your user id is: @USERID'

	["/myuser"]='echo Your username is: @USERNAME'

	["/ping ([a-zA-Z0-9]+)"]='echo Pong: @R1'

	["/uptime"]="uptime"

)

# + end config
# +
# +
# +

FIRSTTIME=0;
BOTPATH="$( cd "$( dirname "$0" )" && pwd )"

echo "+"
while getopts :ht:c: OPTION; do
	case $OPTION in
		h)
			echo " BaTbot: Bash Telegram Bot"
			echo "+"
			echo " Usage: ${0} [-t <token>] [-c <seconds>]"
			exit;
		;;
		t)
			echo "Set Token to: ${OPTARG}";
			TELEGRAMTOKEN=$OPTARG;
		;;
		c)
			echo "Check for new messages every: ${OPTARG} seconds";
			CHECKNEWMSG=$OPTARG;
		;;
	esac
done
echo "+"

echo -en "\n"

echo ".-------------------------------------------------."
echo "| BaTbot v${VERSION}                                   |" 
echo "| Author: theMiddle                               |"
echo "| Twitter: https://twitter.com/Menin_TheMiddle    |"
echo "| Github: https://github.com/theMiddleBlue/BaTbot |"
echo -e "._________________________________________________.\n"

ABOUTME=`curl -s "https://api.telegram.org/bot${TELEGRAMTOKEN}/getMe"`
if [[ "$ABOUTME" =~ \"ok\"\:true\, ]]; then
	if [[ "$ABOUTME" =~ \"username\"\:\"([^\"]+)\" ]]; then
		MYUSERNAME=${BASH_REMATCH[1]}
		echo -e "Username: ${BASH_REMATCH[1]}";
	fi

	if [[ "$ABOUTME" =~ \"first_name\"\:\"([^\"]+)\" ]]; then
		MYFIRSTNAME=${BASH_REMATCH[1]}
		echo -e "First name: ${BASH_REMATCH[1]}";
	fi

	if [[ "$ABOUTME" =~ \"id\"\:([0-9\-]+), ]]; then
		echo "Bot ID: ${BASH_REMATCH[1]}";
		BOTID=${BASH_REMATCH[1]};
	fi

else
	echo "Error: maybe wrong token... exit.";
	exit;
fi

LASTFCOUNT=$(ls -1 ${BOTPATH}/lastid/*.lastmsg 2>/dev/null | wc -l)
if [ $LASTFCOUNT -eq 0 ]; then
	FIRSTTIME=0;
else
	FIRSTTIME=1;
fi

echo -e "Done. Waiting for new messages...\n"

MSGID=0;
CHATID=0;
TEXT=0;
FIRSTNAME="";
LASTNAME="";

while true; do
	MSGOUTPUT=$(curl -s "https://api.telegram.org/bot${TELEGRAMTOKEN}/getUpdates" | bash ${BOTPATH}/inc/JSON.sh -b);

	echo -e "${MSGOUTPUT}" | while read -r line ; do
		LASTLINERCVD=${line};

		if [[ "$line" =~ ^\[\"result\"\,[0-9]+\,\"message\"\,\"message\_id\"\][[:space:]]+([0-9]+) ]]; then
			MSGID=${BASH_REMATCH[1]};
		fi

		if [[ "$line" =~ ^\[\"result\"\,[0-9]+\,\"message\"\,\"chat\"\,\"id\"\][[:space:]]+([0-9\-]+)$ ]]; then
			CHATID=${BASH_REMATCH[1]};
			if [ ! -f ${BOTPATH}/lastid/${BOTID}-${CHATID}.lastmsg ]; then
				echo -n 0 > ${BOTPATH}/lastid/${BOTID}-${CHATID}.lastmsg
			fi
		fi

		if [[ "$line" =~ ^\[\"result\"\,[0-9]+\,\"message\"\,\"from\"\,\"id\"\][[:space:]]+([0-9]+)$ ]]; then
			FROMID=${BASH_REMATCH[1]};
		fi

		if [[ "$line" =~ ^\[\"result\"\,[0-9]+\,\"message\"\,\"from\"\,\"first\_name\"\][[:space:]]+\"(.+)\"$ ]]; then
			FIRSTNAME=${BASH_REMATCH[1]};
		fi

		if [[ "$line" =~ ^\[\"result\"\,[0-9]+\,\"message\"\,\"from\"\,\"last\_name\"\][[:space:]]+\"(.+)\"$ ]]; then
			LASTNAME=${BASH_REMATCH[1]};
		fi

		if [[ "$line" =~ ^\[\"result\"\,[0-9]+\,\"message\"\,\"from\"\,\"username\"\][[:space:]]+\"(.+)\"$ ]]; then
			USERNAME=${BASH_REMATCH[1]};
		fi

		if [[ "$line" =~ ^\[\"result\"\,[0-9]+\,\"message\"\,\"text\"\][[:space:]]+\"(.+)\"$ ]]; then
			TEXT=${BASH_REMATCH[1]};


			if [[ $MSGID -ne 0 && $CHATID -ne 0 ]]; then
				LASTMSGID=$(cat "${BOTPATH}/lastid/${BOTID}-${CHATID}.lastmsg");
				if [[ $MSGID -gt $LASTMSGID ]]; then
					#echo -ne "\r\033[K"
					FIRSTNAMEUTF8=$(echo -e "$FIRSTNAME");
					echo -n "[chat "; printf "%-12s" "${CHATID}"; echo "] <@${USERNAME}> (${FIRSTNAMEUTF8} ${LASTNAME}): ${TEXT}";
					echo $MSGID > "${BOTPATH}/lastid/${BOTID}-${CHATID}.lastmsg";

					for s in "${!botcommands[@]}"; do
						if [[ "$TEXT" =~ ${s} ]]; then
							CMDORIG=${botcommands["$s"]};
							CMDORIG=${CMDORIG//@USERID/$FROMID};
							CMDORIG=${CMDORIG//@USERNAME/$USERNAME};
							CMDORIG=${CMDORIG//@FIRSTNAME/$FIRSTNAMEUTF8};
							CMDORIG=${CMDORIG//@LASTNAME/$LASTNAME};
							CMDORIG=${CMDORIG//@CHATID/$CHATID};
							CMDORIG=${CMDORIG//@MSGID/$MSGID};
							CMDORIG=${CMDORIG//@TEXT/$TEXT};
							CMDORIG=${CMDORIG//@FROMID/$FROMID};
							CMDORIG=${CMDORIG//@R1/${BASH_REMATCH[1]}};
							CMDORIG=${CMDORIG//@R2/${BASH_REMATCH[2]}};
							CMDORIG=${CMDORIG//@R3/${BASH_REMATCH[3]}};

							echo "Command ${s} received, running cmd: ${CMDORIG}"
							CMDOUTPUT=`$CMDORIG`;

							if [ $FIRSTTIME -eq 1 ]; then
								echo "old message, i will not send any answer to user.";
							else
								curl -s -d "text=${CMDOUTPUT}&chat_id=${CHATID}" "https://api.telegram.org/bot${TELEGRAMTOKEN}/sendMessage" > /dev/null
							fi
						fi
					done


					#echo -ne "\r\033[K"
					#clr_green "${MYUSERNAME}" -n; echo -en "> "

				fi
			fi
		fi
	done

	FIRSTTIME=0;

	read -t $CHECKNEWMSG answer;
	if [[ "$answer" =~ ^\.msg.([\-0-9]+).(.*) ]]; then
		CHATID=${BASH_REMATCH[1]};
		MSGSEND=${BASH_REMATCH[2]};
		curl -s -d "text=${MSGSEND}&chat_id=${CHATID}" "https://api.telegram.org/bot${TELEGRAMTOKEN}/sendMessage" > /dev/null;
	elif [[ "$answer" =~ ^\.msg.([a-zA-Z]+).(.*) ]]; then
		CHATID=${BASH_REMATCH[1]};
		MSGSEND=${BASH_REMATCH[2]};
		curl -s -d "text=${MSGSEND}&chat_id=@${CHATID}" "https://api.telegram.org/bot${TELEGRAMTOKEN}/sendMessage" > /dev/null;
	fi

	sleep $CHECKNEWMSG
done
