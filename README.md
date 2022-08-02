# AutoSprayWithCME

This script automates and performs a secure password spraying using crackmapexec on all domain users who have attempts to enter the password incorrectly

## Get users for password spraying
Is user available for password spraying?

```
if user_badpwdtime < (Account Lockout Threshold * 0.4) -> True
```

## Using
```
./spray.sh 10.10.10.10 John.Doe P@ssw0rd
```

## TODO
Some notes on what I want to add in the future

- Determine what is using on password policy, minutes or hours.
- Less verbose output
