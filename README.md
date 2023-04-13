# Launchpad step-by-step

1. deploy USDT (or get the address from the USDT token)
2. deploy projectToken
3. deploy the Launchpad with all the following constructor arguments(check verifyLaunchpad.js): 1. percentage for the liquidity pool(this is taken from the total usdt collected in the contract), 2. address of the usdt token, 3. address of the project token, 4. price of the project token (in usdt) 5. minimum amount of project token that can be purchased by the user 6. Payees = an array with the addresses (or partnerts) that will get paid in usdt
   example: [libertumAddress, projectOwnerAddress, otherAddress] 7. Shares = an array with the shares (IN THE SAME ORDER AS Payees)
   example: [34,33,33] (the sum of the shares MUST be equal to 100)
   Notes --> the amount of USDT that will be distributed for the partners, is taken from the difference of the USDT collected and the "USDT_PERCENTAGE_FOR_LP"(variable #1)
   example:
   USDT_PERCENTAGE_FOR_LP = 70
   we collected 50.000usd in the contract
   owners = [libertum, projectOwner, otherPartner]
   shares = [50,25,25]
   -(Libertum = 50% of shares) (projectOwner = 25% of shares) (otherParner = 25% of shares)
   -USDT for the LiquidityPool = 35.000usdt (50.000 _ 70 / 100) (70% of 50k)
   -USDT for the partners = 15.000usdt
   -USDT for libertum = 7.500usdt == (15.000 _ 50 / 100) == (50% of 15k)
   -USDT for projectOwner = 3.750usdt == (15.000 _ 25 / 100) == (25% of 15k)
   -USDT for otherPartner = 3.750usdt == (15.000 _ 25 / 100)

# Contrato de levantamiento capital

### Ownable - no admins

### NO staking para el launchpad (free)

### Set % liquidity pool

### Set % para la empresa

### Set % para el proyecto

# Liquidity pool con Router y Factory

### Una vez finalizado el levantamiento de capita, se enlista el token en el dex
