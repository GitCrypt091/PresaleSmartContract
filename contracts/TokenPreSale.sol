// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenPreSale is ReentrancyGuard, Ownable {
    uint256 public presaleId;
    uint256 public BASE_MULTIPLIER;
    uint256 public MONTH;
    address public WETH;
    address public ROUTER;

    struct PresaleTiming {
        uint256 startTimePhase1;
        uint256 endTimePhase1;
        uint256 startTimePhase2;
        uint256 endTimePhase2;
    }

    struct PresaleData {
        address saleToken;
        uint256 price;
        uint256 tokensToSell;
        uint256 maxAmountTokensForSalePerUser;
        uint256 amountTokensForLiquidity;
        uint256 baseDecimals;
        uint256 inSale;
    }

    struct PresaleVesting {
        uint256 vestingStartTime;
        uint256 vestingCliff;
        uint256 vestingPeriod;
    }
    

    struct PresaleBuyData {
        uint256 marketingPercentage;
        bool presaleFinalized;
        address[] whitelist;
    }

    struct Presale {
    PresaleTiming presaleTiming;
    PresaleData presaleData;
    PresaleVesting presaleVesting;
    PresaleBuyData presaleBuyData;
    }

    struct Vesting {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 claimStart;
        uint256 claimEnd;
    }

    mapping(uint256 => bool) public paused;
    mapping(uint256 => Presale) public presale;
    mapping(address => mapping(uint256 => Vesting)) public userVesting;

    /**
     * @dev Initializes the contract and sets key parameters
     * @param _router Router contract to add liquidity to
     * @param _weth WETH address
     */
    function initialize(address _weth, address _router) external {
        BASE_MULTIPLIER = (10**18);
        MONTH = (30 * 24 * 3600);
        WETH = _weth;
        ROUTER = _router;
    }

    /**
     * @dev Creates a new presale
     * @param _price Per token price multiplied by (10**18). how much ETH does 1 token cost
     * @param _tokensToSell No of tokens to sell without denomination. If 1 million tokens to be sold then - 1_000_000 has to be passed
     * @param _maxAmountTokensForSalePerUser Max no of tokens someone can buy
     * @param _amountTokensForLiquidity Amount of tokens for liquidity
     * @param _baseDecimals No of decimals for the token. (10**18), for 18 decimal token
     * @param _vestingCliff Cliff period for vesting in seconds
     * @param _vestingPeriod Total vesting period(after vesting cliff) in seconds
     * @param _marketingPercentage Percentage of raised funds that will go to the team
     * @param _presaleFinalized false by default, can only be true after liquidity has been added
     * @param _whitelist array of addresses that are allowed to buy in phase 1
     */
    function createPresale(
        uint256 _price,
        uint256 _tokensToSell,
        uint256 _maxAmountTokensForSalePerUser,
        uint256 _amountTokensForLiquidity,
        uint256 _baseDecimals,
        uint256 _inSale,
        uint256 _vestingCliff,
        uint256 _vestingPeriod,
        uint256 _marketingPercentage,
        bool _presaleFinalized,
        address[] memory _whitelist
    ) external onlyOwner {
        require(validatePrice(_price), "Zero price");
        require(validateMarketingPercentage(_marketingPercentage), "Can not be greater than 40 percent");
        require(validatePresaleFinalized(_presaleFinalized), "Presale can not be finalized");
        require(validateTokensToSell(_tokensToSell), "Zero tokens to sell");
        require(validateBaseDecimals(_baseDecimals), "Zero decimals for the token");
        
        PresaleTiming memory timing = PresaleTiming(0, 0, 0, 0);
        PresaleData memory data = PresaleData(address(0), _price, _tokensToSell, _maxAmountTokensForSalePerUser, _amountTokensForLiquidity, _baseDecimals, _inSale);
        PresaleVesting memory vesting = PresaleVesting(0, _vestingCliff, _vestingPeriod);
        PresaleBuyData memory buyData = PresaleBuyData(_marketingPercentage, _presaleFinalized, _whitelist);

        presaleId++;

        presale[presaleId] = Presale(timing, data, vesting, buyData);

    }

    /**
     * @dev To add the sale times
     * @param _id Presale id to update
     * @param _startTimePhase1 New start time
     * @param _endTimePhase1 New end time
     * @param _startTimePhase2 New start time
     * @param _endTimePhase2 New end time
     * @param _vestingStartTime new vesting start time
     */
    function addSaleTimes(
    uint256 _id,
    uint256 _startTimePhase1,
    uint256 _endTimePhase1,
    uint256 _startTimePhase2,
    uint256 _endTimePhase2,
    uint256 _vestingStartTime 
    ) external checkPresaleId(_id) onlyOwner {
        require(_startTimePhase1 > 0 || _endTimePhase1 > 0 || _startTimePhase2 > 0 || _endTimePhase2 > 0 || _vestingStartTime > 0, "Invalid parameters");

        if (_startTimePhase1 > 0) {
            require(block.timestamp < _startTimePhase1, "Sale time in past");
            presale[_id].presaleTiming.startTimePhase1 = _startTimePhase1;
        }

        if (_endTimePhase1 > 0) {
            require(block.timestamp < _endTimePhase1, "Sale end in past");
            require(_endTimePhase1 > _startTimePhase1, "Sale ends before sale start");
            presale[_id].presaleTiming.endTimePhase1 = _endTimePhase1;
        }

        if (_startTimePhase2 > 0) {
            require(block.timestamp < _startTimePhase2, "Sale time in past");
            presale[_id].presaleTiming.startTimePhase2 = _startTimePhase2;
        }

        if (_endTimePhase2 > 0) {
            require(block.timestamp < _endTimePhase2, "Sale end in past");
            require(_endTimePhase2 > _startTimePhase2, "Sale ends before sale start");
            presale[_id].presaleTiming.endTimePhase2 = _endTimePhase2;
        }

        if (_vestingStartTime > 0) {
            require(
            _vestingStartTime >= presale[_id].presaleTiming.endTimePhase2,
            "Vesting starts before Presale ends"
        );
            presale[_id].presaleVesting.vestingStartTime = _vestingStartTime;
        }
    }

    /**
     * @dev To update the sale times
     * @param _id Presale id to update
     * @param _startTimePhase1 New start time
     * @param _endTimePhase1 New end time
     * @param _startTimePhase2 New start time
     * @param _endTimePhase2 New end time
     */
    function changeSaleTimes(
    uint256 _id,
    uint256 _startTimePhase1,
    uint256 _endTimePhase1,
    uint256 _startTimePhase2,
    uint256 _endTimePhase2
    ) external checkPresaleId(_id) onlyOwner {
        require(_startTimePhase1 > 0 || _endTimePhase1 > 0 || _startTimePhase2 > 0 || _endTimePhase2 > 0, "Invalid parameters");

        if (_startTimePhase1 > 0) {
            require(
                block.timestamp < presale[_id].presaleTiming.startTimePhase1,
                "Sale already started"
            );
            require(block.timestamp < _startTimePhase1, "Sale time in past");
            presale[_id].presaleTiming.startTimePhase1 = _startTimePhase1;
        }

        if (_endTimePhase1 > 0) {
            require(
                block.timestamp < presale[_id].presaleTiming.endTimePhase1,
                "Sale already ended"
            );
            require(_endTimePhase1 > presale[_id].presaleTiming.startTimePhase1, "Invalid endTime");
            presale[_id].presaleTiming.endTimePhase1 = _endTimePhase1;
        }

        if (_startTimePhase2 > 0) {
            require(
                block.timestamp < presale[_id].presaleTiming.startTimePhase2,
                "Sale already started"
            );
            require(block.timestamp < _startTimePhase2, "Sale time in past");
            presale[_id].presaleTiming.startTimePhase2 = _startTimePhase2;
        }

        if (_endTimePhase2 > 0) {
            require(
                block.timestamp < presale[_id].presaleTiming.endTimePhase2,
                "Sale already ended"
            );
            require(_endTimePhase2 > presale[_id].presaleTiming.startTimePhase2, "Invalid endTime");
            presale[_id].presaleTiming.endTimePhase2 = _endTimePhase2;
        }
    }

    /**
     * @dev To whitelist addresses
     * @param _id Presale id to update
     * @param _wallets Array of wallet addresses
     */
    function addToWhitelist(uint256 _id, address[] memory _wallets)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        for (uint256 i = 0; i < _wallets.length; i++) {
            presale[_id].presaleBuyData.whitelist.push(_wallets[i]);
        }
    }

    /**
     * @dev To remove addresses from the whitelist
     * @param _id Presale id to update
     * @param _wallets Array of wallet addresses
     */
    function removeFromWhitelist(uint256 _id, address[] memory _wallets)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        for (uint256 i = 0; i < _wallets.length; i++) {
            for (uint256 j = 0; j < presale[_id].presaleBuyData.whitelist.length; j++) {
                if (presale[_id].presaleBuyData.whitelist[j] == _wallets[i]) {
                    delete presale[_id].presaleBuyData.whitelist[j];
                    break;
                }
            }
        }
    }

    /**
     * @dev To update the vesting start time
     * @param _id Presale id to update
     * @param _vestingStartTime New vesting start time
     */
    function changeVestingStartTime(uint256 _id, uint256 _vestingStartTime)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        require(
            _vestingStartTime >= presale[_id].presaleTiming.endTimePhase2,
            "Vesting starts before Presale ends"
        );
        presale[_id].presaleVesting.vestingStartTime = _vestingStartTime;
    }

    /**
     * @dev To update the sale token address
     * @param _id Presale id to update
     * @param _newAddress Sale token address
     */
    function changeSaleTokenAddress(uint256 _id, address _newAddress)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        require(_newAddress != address(0), "Zero token address");
        presale[_id].presaleData.saleToken = _newAddress;
    }

    /**
     * @dev To update the price
     * @param _id Presale id to update
     * @param _newPrice New sale price of the token
     */
    function changePrice(uint256 _id, uint256 _newPrice)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        require(_newPrice > 0, "Zero price");
        require(
            presale[_id].presaleTiming.startTimePhase1 > block.timestamp,
            "Sale already started"
        );
        require(
            presale[_id].presaleTiming.startTimePhase2 > block.timestamp,
            "Sale already started"
        );
        presale[_id].presaleData.price = _newPrice;
    }

     /**
     * @dev To update the amount of tokens that will be added to liquidity
     * @param _id Presale id to update
     * @param _newAmountTokensForLiquidity new amount
     */
    function changeAmountTokensForLiquidity(uint256 _id, uint256 _newAmountTokensForLiquidity)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        presale[_id].presaleData.maxAmountTokensForSalePerUser = _newAmountTokensForLiquidity;
    }

     /**
     * @dev To update the marketing percentage that will go to the team
     * @param _id Presale id to update
     * @param _newMarketingPercentage The new marketing percentage
     */
    function changeMarketingPercentage(uint256 _id, uint256 _newMarketingPercentage)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        presale[_id].presaleBuyData.marketingPercentage = _newMarketingPercentage;
    }

     /**
     * @dev To update the max amount of tokens someone can buy
     * @param _id Presale id to update
     * @param _newMaxAmountTokensForSalePerUser New max amount 
     */
    function changeMaxAmountTokensForSalePerUser(uint256 _id, uint256 _newMaxAmountTokensForSalePerUser)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        require(_newMaxAmountTokensForSalePerUser < presale[_id].presaleData.tokensToSell, "number too big");
        require(
            presale[_id].presaleTiming.startTimePhase1 > block.timestamp,
            "Sale already started"
        );
        require(
            presale[_id].presaleTiming.startTimePhase2 > block.timestamp,
            "Sale already started"
        );
        presale[_id].presaleData.maxAmountTokensForSalePerUser = _newMaxAmountTokensForSalePerUser;
    }


    /**
     * @dev To pause the presale
     * @param _id Presale id to update
     */
    function pausePresale(uint256 _id) external checkPresaleId(_id) onlyOwner {
        require(!paused[_id], "Already paused");
        paused[_id] = true;
    }

    /**
     * @dev To unpause the presale
     * @param _id Presale id to update
     */
    function unPausePresale(uint256 _id)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        require(paused[_id], "Not paused");
        paused[_id] = false;
    }

    /**
     * @dev To finalize the sale by adding the tokens to liquidity and sending the marketing percentage to the team
     * @param _id Presale id to update
     */
    function finalizeAndAddLiquidity(uint256 _id)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        require(presale[_id].presaleBuyData.presaleFinalized == false, "already finalized");
        transferMarketingFunds(_id);
        addLiquidity(_id);
    }

    function validateTiming(PresaleTiming memory _timing) internal view returns (bool) {
        if (_timing.startTimePhase1 <= block.timestamp || _timing.endTimePhase1 <= _timing.startTimePhase1) return false;
        if (_timing.startTimePhase2 <= block.timestamp || _timing.endTimePhase2 <= _timing.startTimePhase2) return false;
        return true;
    }

    function validatePrice(uint256 _price) internal pure returns (bool) {
        return _price > 0;
    }

    function validateMarketingPercentage(uint256 _marketingPercentage) internal pure returns (bool) {
        return _marketingPercentage <= 40;
    }

    function validatePresaleFinalized(bool _presaleFinalized) internal pure returns (bool) {
        return !_presaleFinalized;
    }

    function validateTokensToSell(uint256 _tokensToSell) internal pure returns (bool) {
        return _tokensToSell > 0;
    }

    function validateBaseDecimals(uint256 _baseDecimals) internal pure returns (bool) {
        return _baseDecimals > 0;
    }

    function validateVesting(uint256 _vestingStartTime, uint256 endTimePhase2) internal pure returns (bool) {
        return _vestingStartTime >= endTimePhase2;
    }

    function transferMarketingFunds(uint256 _id) internal {

        uint256 ETHBalance = address(this).balance;

        uint256 marketingAmountETH = ETHBalance * (presale[_id].presaleBuyData.marketingPercentage / 100);

        if (ETHBalance > 0) {
            address payable teamAddress = payable(owner());
            teamAddress.transfer(marketingAmountETH);
        }
    }


    function addLiquidity(uint256 _id) internal {
        address saleTokenAddress = presale[_id].presaleData.saleToken;
        uint256 ETHBalance = address(this).balance;

        // allowance
        (bool successAllowanceSaleToken, ) = address(saleTokenAddress).call(
            abi.encodeWithSignature(
                "approve(address,uint256)",
                ROUTER,
                presale[_id].presaleData.amountTokensForLiquidity
            )
        );

        // add liquidity
        (bool successAddLiq, ) = address(ROUTER).call{value: ETHBalance}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                presale[_id].presaleData.saleToken,
                presale[_id].presaleData.amountTokensForLiquidity,
                0,
                0,
                owner(),
                block.timestamp + 600
            )
        );
    }


    modifier checkPresaleId(uint256 _id) {
        require(_id > 0 && _id <= presaleId, "Invalid presale id");
        _;
    }

    modifier checkSaleState(uint256 _id, uint256 amount) {
        require(
            block.timestamp >= presale[_id].presaleTiming.startTimePhase1 &&
                block.timestamp <= presale[_id].presaleTiming.endTimePhase2,
            "Invalid time for buying"
        );
        require(
            amount > 0 && amount <= presale[_id].presaleData.inSale,
            "Invalid sale amount"
        );
        _;
    }

    function isWhitelisted(uint256 _id, address _address) internal view returns (bool) {
        for (uint256 i = 0; i < presale[_id].presaleBuyData.whitelist.length; i++) {
            if (presale[_id].presaleBuyData.whitelist[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function isPhaseOne(uint256 _id) internal view returns (bool) {
        if (presale[_id].presaleTiming.startTimePhase1 > block.timestamp && presale[_id].presaleTiming.endTimePhase1 < block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev To buy into a presale using ETH
     * @param _id Presale id
     * @param amount No of tokens to buy. not in wei
     */
    function buyWithEth(uint256 _id, uint256 amount)
        external
        payable
        checkPresaleId(_id)
        checkSaleState(_id, amount)
        nonReentrant
        returns (bool)
    {
        require(amount <= presale[_id].presaleData.maxAmountTokensForSalePerUser, "You are trying to buy too many tokens");
        require(!paused[_id], "Presale paused");
        uint256 ethAmount = amount * presale[_id].presaleData.price;
        require(msg.value >= ethAmount, "Less payment");
        uint256 excess = msg.value - ethAmount;
        presale[_id].presaleData.inSale -= amount;
        Presale memory _presale = presale[_id];

        if (isPhaseOne(_id)) {
            require(isWhitelisted(_id, msg.sender), "Not whitelisted");
        }

        if (userVesting[_msgSender()][_id].totalAmount > 0) {
        userVesting[_msgSender()][_id].totalAmount += (amount *
            _presale.presaleData.baseDecimals);
        } else {
            userVesting[_msgSender()][_id] = Vesting(
                (amount * _presale.presaleData.baseDecimals),
                0,
                _presale.presaleVesting.vestingStartTime + _presale.presaleVesting.vestingCliff,
                _presale.presaleVesting.vestingStartTime +
                    _presale.presaleVesting.vestingCliff +
                    _presale.presaleVesting.vestingPeriod
            );
        }
        sendValue(payable(address(this)), ethAmount);
        if (excess > 0) sendValue(payable(_msgSender()), excess);
        return true;
    }


    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH Payment failed");
    }

    /**
     * @dev Helper funtion to get claimable tokens for a given presale.
     * @param user User address
     * @param _id Presale id
     */
    function claimableAmount(address user, uint256 _id)
        public
        view
        checkPresaleId(_id)
        returns (uint256)
    {
        Vesting memory _user = userVesting[user][_id];
        require(_user.totalAmount > 0, "Nothing to claim");
        uint256 amount = _user.totalAmount - _user.claimedAmount;
        require(amount > 0, "Already claimed");

        if (block.timestamp < _user.claimStart) return 0;
        if (block.timestamp >= _user.claimEnd) return amount;

        uint256 noOfMonthsPassed = (block.timestamp - _user.claimStart) / MONTH;

        uint256 perMonthClaim = (_user.totalAmount * BASE_MULTIPLIER * MONTH) /
            (_user.claimEnd - _user.claimStart);

        uint256 amountToClaim = ((noOfMonthsPassed * perMonthClaim) /
            BASE_MULTIPLIER) - _user.claimedAmount;

        return amountToClaim;
    }

    /**
     * @dev To claim tokens after vesting cliff from a presale
     * @param user User address
     * @param _id Presale id
     */
    function claim(address user, uint256 _id) public returns (bool) {
        uint256 amount = claimableAmount(user, _id);
        require(presale[_id].presaleBuyData.presaleFinalized == true, "Liquidity has not been added yet");
        require(amount > 0, "Zero claim amount");
        require(
            presale[_id].presaleData.saleToken != address(0),
            "Presale token address not set"
        );
        require(
            amount <=
                IERC20(presale[_id].presaleData.saleToken).balanceOf(
                    address(this)
                ),
            "Not enough tokens in the contract"
        );
        userVesting[user][_id].claimedAmount += amount;
        bool status = IERC20(presale[_id].presaleData.saleToken).transfer(
            user,
            amount
        );
        require(status, "Token transfer failed");
        return true;
    }

    /**
     * @dev To claim tokens after vesting cliff from a presale
     * @param users Array of user addresses
     * @param _id Presale id
     */
    function claimMultiple(address[] calldata users, uint256 _id)
        external
        returns (bool)
    {
        require(presale[_id].presaleBuyData.presaleFinalized == true, "Liquidity has not been added yet");
        require(users.length > 0, "Zero users length");
        for (uint256 i; i < users.length; i++) {
            require(claim(users[i], _id), "Claim failed");
        }
        return true;
    }
}