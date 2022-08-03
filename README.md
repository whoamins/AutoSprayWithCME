# AutoSprayWithCME

This script automates and performs a secure password spraying using [CrackMapExec](https://github.com/Porchetta-Industries/CrackMapExec) on all domain users who have attempts to enter the password incorrectly

**WARNING:** **The script may contain a bug that will ban accounts. The script hasn't yet passed the full debugging cycle.**


## Get users for password spraying
Is user available for password spraying?

```
if user_badpwdtime < (Account Lockout Threshold * 0.4) -> True
```

## Using
To use it, you need to install [CrackMapExec](https://github.com/Porchetta-Industries/CrackMapExec)

```
sudo apt-get install crackmapexec
```

```
./spray.sh 10.10.10.10 John.Doe P@ssw0rd
```

## TODO
Some notes on what I want to add in the future

- Determine what is using on password policy, minutes or hours.
- Less verbose output
- Spray without domain account using username wordlist
