# Launchpad step-by-step

    1. deploy USDT (or get the address from the USDT token)
    2. deploy projectToken
    3. deploy the Launchpad with all the following constructor arguments(check scripts/verifyLaunchpad.js):
        1. USDT_PERCENTAGE_FOR_LP = percentage for the liquidity pool(this is taken from the total usdt collected in the contract),
        2. address of the usdt token,
        3. address of the project token,
        4. price of the project token (in usdt)
        5. minimum amount of project token that can be purchased by the user
        6. Payees = an array with the addresses (or partnerts) that will get paid in usdt
            example: [libertumAddress, projectOwnerAddress, otherAddress]
        7. Shares = an array with the shares (IN THE SAME ORDER AS Payees)
            example: [34,33,33] (the sum of the shares MUST be equal to 100)
    4. approve() projectToken from the projectOwner, so the launchpad is able to get the token
    5. call addSupplyToSell(amount), this is the projecToken amount that will be sold in the launchpad
    6. call addSupplyForLP(amount), this is the projectToken amount that will be send to the LP pancakeswap
    7. now users can call buyTokens() - users MUST approve() the USDT contract first so the launchpad can take their USDT to buy projectToken
    8. once the projectToken has been sold, (or even before, but not ideal) the Owner of the launchpad(deployer) can call finishRound()
    9. finishRound() will distribute the funds to the partners and call factory & router in pancakeSwap
    10. after round is closed, users can call claimTokens() and the tokens will be transfered to their wallets

    Notes --> the amount of USDT that is distributed among the partners, is taken from the difference of the USDT collected and the USDT for the liquidity pool (percentage)

    example:
        owners = [libertum, projectOwner, otherPartner]
        shares = [50,25,25]
        -Shares distribution:
            -libertum = 50% of shares
            -projectOwner = 25% of shares
            -otherParner = 25% of shares

        USDT_PERCENTAGE_FOR_LP = 70.
        we collected 50.000usd in the contract.

        -USDT for the LiquidityPool = 35.000usdt (70% of 50k)

        -USDT for ALL the partners = 15.000usdt (30% of 50k)

        -USDT for libertum = 7.500usdt (50% of 15k)
        -USDT for projectOwner = 3.750usdt (25% of 15k)
        -USDT for otherPartner = 3.750usdt (25% of 15k)

