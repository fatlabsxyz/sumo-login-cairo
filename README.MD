# SUMO - Cairo Contracts
These are the cairo contracts that are used in [SUMO](sumologin.com)


## Overall architecture
The necessary contracts for the SUMO flow are two:

- The SUMO Account contract: These accounts are meant to be used by users of SUMO. They can be deployed or accessed by the user after an OAuth authorization (like login to a google account). After that they function like a regular account.

- The SUMO Login contract: This contract is an account that works as kind of paymaster. This account is capable of deploy SUMO Accounts or log in users to theirs SUMO accounts. 


### The SUMO Login contract
This contract is responsible for:

- Deploy: When new users want to deploy an account they have to provide a JWT signed first by the OAuth provider and then by a newly generated  ephemeral key pair . The Login contract verifies that this data is correct and deploys a SUMO Account for the user to use. The new account uses the provided ephemeral  key pair to sign/verify its transactions.

- Login: When users with a previously deployed SUMO Account wants to use their account and they do not have the ephemeral key (maybe because they are trying to use a the account in a diferent device), they can provide a new JWT with a new ephemeral key pair. The Login contract verifies then that the data is correct and changes the key of the users account to the new one. The user can now use the ephemeral key pair to sign-verify its transactions.

To keep private the content of the JWT. The users do not provide the raw JWT but a zk poof that guarantees that they are in posetion of the JWT. This is the main feature of SUMO.

### The SUMO Account contract.
Once deployed, this account functions in a similar way to a regular account. The user can make transactions that are signed with the ephemeral private key. The ephemeral key has a expiration block that can be set by the user on deploy/login.

If the users want to use theirs account in another device, they do not need to remember a passphrase or ephemeral key. They can simply login again with their OAuth provider, the SUMO Login contract will verify the zk proof and set the new key of the account to the new ephemeral key provided.

### Repay Mechanisms
At the moment, the Login contract pays upfront the cost of deploy/login a SUMO Account contract. The SUMO accounts have a repay mechanisms that is transparent to the user. The Login contract keeps tracks of all the users debt. Debts increase only with deploy/login operations. When SUMO Accounts try to execute a transactions, they are forced to pay they debts. If they can't the transaction is not executed.
