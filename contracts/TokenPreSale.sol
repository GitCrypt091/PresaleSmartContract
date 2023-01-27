// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenPreSale is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    uint256 public presaleId;
    uint256 public BASE_MULTIPLIER;
    uint256 public MONTH;
    address public WETH;
    

    struct Presale {
        address saleToken;
        uint256 startTimePhase1;
        uint256 endTimePhase1;
        uint256 startTimePhase2;
        uint256 endTimePhase2;
        uint256 price;
        uint256 tokensToSell;
        uint256 maxAmountTokensForSalePerUser;
        uint256 amountTokensForLiquidity;
        uint256 baseDecimals;
        uint256 inSale;
        uint256 vestingStartTime;
        uint256 vestingCliff;
        uint256 vestingPeriod;
        uint256 enableBuyWithEth;
        uint256 enableBuyWithUsdt;
        uint256 marketingPercentage;
        bool presaleFinalized;
        address[] whitelist;
    }

    struct Vesting {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 claimStart;
        uint256 claimEnd;
    }

    IERC20Upgradeable public USDTInterface;
    IERC20Upgradeable public RouterInterface;
    AggregatorV3Interface internal aggregatorInterface; // https://docs.chain.link/docs/ethereum-addresses/ => (ETH / USD)

    mapping(uint256 => bool) public paused;
    mapping(uint256 => Presale) public presale;
    mapping(address => mapping(uint256 => Vesting)) public userVesting;

    event AddedToWhitelist(
        uint256 id,
        address[] wallets
    );

    event RemovedFromWhitelist(
        uint256 id,
        address[] wallets
    );

    event PresaleCreated(
        uint256 indexed _id,
        uint256 _totalTokens,
        uint256 _maxTokensSell,
        uint256 _tokensForLiquidity,
        uint256 _startTime1,
        uint256 _endTime1,
        uint256 _startTime2,
        uint256 _endTime2,
        uint256 enableBuyWithEth,
        uint256 enableBuyWithUsdt
    );

    event PresaleUpdated(
        bytes32 indexed key,
        uint256 prevValue,
        uint256 newValue,
        uint256 timestamp
    );

    event TokensBought(
        address indexed user,
        uint256 indexed id,
        address indexed purchaseToken,
        uint256 tokensBought,
        uint256 amountPaid,
        uint256 timestamp
    );

    event TokensClaimed(
        address indexed user,
        uint256 indexed id,
        uint256 amount,
        uint256 timestamp
    );

    event PresaleTokenAddressUpdated(
        address indexed prevValue,
        address indexed newValue,
        uint256 timestamp
    );

    event PresalePaused(uint256 indexed id, uint256 timestamp);
    event PresaleUnpaused(uint256 indexed id, uint256 timestamp);
    event PresaleFinalized(uint256 indexed id, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev Initializes the contract and sets key parameters
     * @param _oracle Oracle contract to fetch ETH/USDT price
     * @param _usdt USDT token contract address
     * @param _router Router contract to add liquidity to
     * @param _weth WETH address
     */
    function initialize(address _oracle, address _usdt, address _router, address _weth) external initializer {
        require(_oracle != address(0), "Zero aggregator address");
        require(_usdt != address(0), "Zero USDT address");
        require(_router != address(0), "Zero router address");
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        aggregatorInterface = AggregatorV3Interface(_oracle);
        USDTInterface = IERC20Upgradeable(_usdt);
        RouterInterface = IERC20Upgradeable(_router);
        BASE_MULTIPLIER = (10**18);
        MONTH = (30 * 24 * 3600);
        WETH = _weth;
    }

    /**
     * @dev Creates a new presale
     * @param _startTimePhase1 start time of the sale
     * @param _endTimePhase1 end time of the sale
     * @param _startTimePhase2 start time of the sale
     * @param _endTimePhase2 end time of the sale
     * @param _price Per token price multiplied by (10**18)
     * @param _tokensToSell No of tokens to sell without denomination. If 1 million tokens to be sold then - 1_000_000 has to be passed
     * @param _maxAmountTokensForSalePerUser Max no of tokens someone can buy
     * @param _amountTokensForLiquidity Amount of tokens for liquidity
     * @param _baseDecimals No of decimals for the token. (10**18), for 18 decimal token
     * @param _vestingStartTime Start time for the vesting - UNIX timestamp
     * @param _vestingCliff Cliff period for vesting in seconds
     * @param _vestingPeriod Total vesting period(after vesting cliff) in seconds
     * @param _enableBuyWithEth Enable/Disable buy of tokens with ETH
     * @param _enableBuyWithUsdt Enable/Disable buy of tokens with USDT
     * @param _marketingPercentage Percentage of raised funds that will go to the team
     * @param _presaleFinalized false by default, can only be true after liquidity has been added
     * @param _whitelist array of addresses that are allowed to buy in phase 1
     */
    function createPresale(
        uint256 _startTimePhase1,
        uint256 _endTimePhase1,
        uint256 _startTimePhase2,
        uint256 _endTimePhase2,
        uint256 _price,
        uint256 _tokensToSell,
        uint256 _maxAmountTokensForSalePerUser,
        uint256 _amountTokensForLiquidity,
        uint256 _baseDecimals,
        uint256 _inSale,
        uint256 _vestingStartTime,
        uint256 _vestingCliff,
        uint256 _vestingPeriod,
        uint256 _enableBuyWithEth,
        uint256 _enableBuyWithUsdt,
        uint256 _marketingPercentage,
        bool _presaleFinalized,
        address[] memory _whitelist
    ) external onlyOwner {
        require (_tokensToSell == _inSale, "tokensToSell must be equal to inSale");
        require(
            _startTimePhase1 > block.timestamp && _endTimePhase1 > _startTimePhase1,
            "Invalid time"
        );
        require(
            _startTimePhase2 > block.timestamp && _endTimePhase2 > _startTimePhase2,
            "Invalid time"
        );
        require(_price > 0, "Zero price");
        require(_marketingPercentage < 40, "Can not be greater than 40 percent");
        require(_presaleFinalized == false, "Presale can not be finalized");
        require(_tokensToSell > 0, "Zero tokens to sell");
        require(_baseDecimals > 0, "Zero decimals for the token");
        require(
            _vestingStartTime >= _endTimePhase2,
            "Vesting starts before Presale ends"
        );

        presaleId++;

        presale[presaleId] = Presale(
            address(0),
            _startTimePhase1,
            _endTimePhase1,
            _startTimePhase2,
            _endTimePhase2,
            _price,
            _tokensToSell,
            _maxAmountTokensForSalePerUser,
            _amountTokensForLiquidity,
            _baseDecimals,
            _inSale,
            _vestingStartTime,
            _vestingCliff,
            _vestingPeriod,
            _enableBuyWithEth,
            _enableBuyWithUsdt,
            _marketingPercentage,
            _presaleFinalized,
            _whitelist
        );

        emit PresaleCreated(presaleId, _tokensToSell, _maxAmountTokensForSalePerUser, _amountTokensForLiquidity, _startTimePhase1, _endTimePhase1, _startTimePhase2, _endTimePhase2, _enableBuyWithEth, _enableBuyWithUsdt);
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
                block.timestamp < presale[_id].startTimePhase1,
                "Sale already started"
            );
            require(block.timestamp < _startTimePhase1, "Sale time in past");
            uint256 prevValue = presale[_id].startTimePhase1;
            presale[_id].startTimePhase1 = _startTimePhase1;
            emit PresaleUpdated(
                bytes32("START"),
                prevValue,
                _startTimePhase1,
                block.timestamp
            );
        }

        if (_endTimePhase1 > 0) {
            require(
                block.timestamp < presale[_id].endTimePhase1,
                "Sale already ended"
            );
            require(_endTimePhase1 > presale[_id].startTimePhase1, "Invalid endTime");
            uint256 prevValue = presale[_id].endTimePhase1;
            presale[_id].endTimePhase1 = _endTimePhase1;
            emit PresaleUpdated(
                bytes32("END"),
                prevValue,
                _endTimePhase1,
                block.timestamp
            );
        }
        if (_startTimePhase2 > 0) {
            require(
                block.timestamp < presale[_id].startTimePhase2,
                "Sale already started"
            );
            require(block.timestamp < _startTimePhase2, "Sale time in past");
            uint256 prevValue = presale[_id].startTimePhase2;
            presale[_id].startTimePhase2 = _startTimePhase2;
            emit PresaleUpdated(
                bytes32("START"),
                prevValue,
                _startTimePhase2,
                block.timestamp
            );
        }

        if (_endTimePhase2 > 0) {
            require(
                block.timestamp < presale[_id].endTimePhase2,
                "Sale already ended"
            );
            require(_endTimePhase2 > presale[_id].startTimePhase2, "Invalid endTime");
            uint256 prevValue = presale[_id].endTimePhase2;
            presale[_id].endTimePhase2 = _endTimePhase2;
            emit PresaleUpdated(
                bytes32("END"),
                prevValue,
                _endTimePhase2,
                block.timestamp
            );
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
            presale[_id].whitelist.push(_wallets[i]);
        }
        emit AddedToWhitelist(_id, _wallets);
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
            for (uint256 j = 0; j < presale[_id].whitelist.length; j++) {
                if (presale[_id].whitelist[j] == _wallets[i]) {
                    delete presale[_id].whitelist[j];
                    break;
                }
            }
        }
        emit RemovedFromWhitelist(_id, _wallets);
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
            _vestingStartTime >= presale[_id].endTimePhase2,
            "Vesting starts before Presale ends"
        );
        uint256 prevValue = presale[_id].vestingStartTime;
        presale[_id].vestingStartTime = _vestingStartTime;
        emit PresaleUpdated(
            bytes32("VESTING_START_TIME"),
            prevValue,
            _vestingStartTime,
            block.timestamp
        );
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
        address prevValue = presale[_id].saleToken;
        presale[_id].saleToken = _newAddress;
        emit PresaleTokenAddressUpdated(
            prevValue,
            _newAddress,
            block.timestamp
        );
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
            presale[_id].startTimePhase1 > block.timestamp,
            "Sale already started"
        );
        require(
            presale[_id].startTimePhase2 > block.timestamp,
            "Sale already started"
        );
        uint256 prevValue = presale[_id].price;
        presale[_id].price = _newPrice;
        emit PresaleUpdated(
            bytes32("PRICE"),
            prevValue,
            _newPrice,
            block.timestamp
        );
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
        uint256 prevValue = presale[_id].maxAmountTokensForSalePerUser;
        presale[_id].maxAmountTokensForSalePerUser = _newAmountTokensForLiquidity;
        emit PresaleUpdated(
            bytes32("TOKENSLIQUIDITY"),
            prevValue,
            _newAmountTokensForLiquidity,
            block.timestamp
        );
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
        uint256 prevValue = presale[_id].marketingPercentage;
        presale[_id].marketingPercentage = _newMarketingPercentage;
        emit PresaleUpdated(
            bytes32("MARKETINGPERCENTAGE"),
            prevValue,
            _newMarketingPercentage,
            block.timestamp
        );
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
        require(_newMaxAmountTokensForSalePerUser < presale[_id].tokensToSell, "number too big");
        require(
            presale[_id].startTimePhase1 > block.timestamp,
            "Sale already started"
        );
        require(
            presale[_id].startTimePhase2 > block.timestamp,
            "Sale already started"
        );
        uint256 prevValue = presale[_id].maxAmountTokensForSalePerUser;
        presale[_id].maxAmountTokensForSalePerUser = _newMaxAmountTokensForSalePerUser;
        emit PresaleUpdated(
            bytes32("MAXTOKENS"),
            prevValue,
            _newMaxAmountTokensForSalePerUser,
            block.timestamp
        );
    }

    /**
     * @dev To update possibility to buy with ETH
     * @param _id Presale id to update
     * @param _enableToBuyWithEth New value of enable to buy with ETH
     */
    function changeEnableBuyWithEth(uint256 _id, uint256 _enableToBuyWithEth)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        uint256 prevValue = presale[_id].enableBuyWithEth;
        presale[_id].enableBuyWithEth = _enableToBuyWithEth;
        emit PresaleUpdated(
            bytes32("ENABLE_BUY_WITH_ETH"),
            prevValue,
            _enableToBuyWithEth,
            block.timestamp
        );
    }

    /**
     * @dev To update possibility to buy with Usdt
     * @param _id Presale id to update
     * @param _enableToBuyWithUsdt New value of enable to buy with Usdt
     */
    function changeEnableBuyWithUsdt(uint256 _id, uint256 _enableToBuyWithUsdt)
        external
        checkPresaleId(_id)
        onlyOwner
    {
        uint256 prevValue = presale[_id].enableBuyWithUsdt;
        presale[_id].enableBuyWithUsdt = _enableToBuyWithUsdt;
        emit PresaleUpdated(
            bytes32("ENABLE_BUY_WITH_USDT"),
            prevValue,
            _enableToBuyWithUsdt,
            block.timestamp
        );
    }

    /**
     * @dev To pause the presale
     * @param _id Presale id to update
     */
    function pausePresale(uint256 _id) external checkPresaleId(_id) onlyOwner {
        require(!paused[_id], "Already paused");
        paused[_id] = true;
        emit PresalePaused(_id, block.timestamp);
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
        emit PresaleUnpaused(_id, block.timestamp);
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
        require(presale[_id].presaleFinalized == false, "already finalized");
        address USDTAddress = address(USDTInterface);
        uint256 USDTBalance = USDTAddress.balance;

        uint256 ETHBalance = address(this).balance;
        
        uint256 marketingAmountUSDT = USDTBalance * (presale[_id].marketingPercentage / 100);
        uint256 marketingAmountETH = ETHBalance * (presale[_id].marketingPercentage / 100);

        if (USDTBalance > 0) {
            (bool success, ) = address(USDTInterface).call(
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    address(this),
                    owner(),
                    marketingAmountUSDT
                )
            );
        }

        if (ETHBalance > 0) {
            address payable teamAddress = payable(owner());
            teamAddress.transfer(marketingAmountETH);
        }

        uint256 newUSDTBalance = USDTAddress.balance;
        
        // swap USDT into ETH
        (bool successSwap, ) = address(RouterInterface).call(
                abi.encodeWithSignature(
                    "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
                    newUSDTBalance,
                    0,
                    [USDTAddress, WETH],
                    address(this),
                    999999999999999
                )
            );

        uint256 newETHBalance = address(this).balance;

        // add liquidity
        (bool successAddLiq, ) = address(RouterInterface).call(
                abi.encodeWithSignature(
                    "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                    presale[_id].saleToken,
                    presale[_id].amountTokensForLiquidity,
                    0,
                    0,
                    owner(),
                    999999999999999
                )
            );
        emit PresaleFinalized(_id, block.timestamp);
    }

    /**
     * @dev To get latest ethereum price in 10**18 format
     */
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        price = (price * (10**10));
        return uint256(price);
    }

    modifier checkPresaleId(uint256 _id) {
        require(_id > 0 && _id <= presaleId, "Invalid presale id");
        _;
    }

    modifier checkSaleState(uint256 _id, uint256 amount) {
        require(
            block.timestamp >= presale[_id].startTimePhase1 &&
                block.timestamp <= presale[_id].endTimePhase2,
            "Invalid time for buying"
        );
        require(
            amount > 0 && amount <= presale[_id].inSale,
            "Invalid sale amount"
        );
        _;
    }

    function isWhitelisted(uint256 _id, address _address) internal view returns (bool) {
        for (uint256 i = 0; i < presale[_id].whitelist.length; i++) {
            if (presale[_id].whitelist[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev To buy into a presale using USDT
     * @param _id Presale id
     * @param amount No of tokens to buy
     */
    function buyWithUSDT(uint256 _id, uint256 amount)
        external
        checkPresaleId(_id)
        checkSaleState(_id, amount)
        returns (bool)
    {
        require(amount <= presale[_id].maxAmountTokensForSalePerUser, "You are trying to buy too many tokens");
        require(!paused[_id], "Presale paused");
        require(presale[_id].enableBuyWithUsdt > 0, "Not allowed to buy with USDT");
        uint256 usdPrice = amount * presale[_id].price;
        usdPrice = usdPrice / (10**12);
        presale[_id].inSale -= amount;

        Presale memory _presale = presale[_id];

        // Phase 1 is active and Phase 2 did not start yet. Whitelist required
        if (block.timestamp > presale[_id].startTimePhase1 && block.timestamp < presale[_id].startTimePhase2) {
            require(isWhitelisted(_id, msg.sender), "Not whitelisted");
            if (userVesting[_msgSender()][_id].totalAmount > 0) {
                userVesting[_msgSender()][_id].totalAmount += (amount *
                    _presale.baseDecimals);
            } else {
                userVesting[_msgSender()][_id] = Vesting(
                    (amount * _presale.baseDecimals),
                    0,
                    _presale.vestingStartTime + _presale.vestingCliff,
                    _presale.vestingStartTime +
                        _presale.vestingCliff +
                        _presale.vestingPeriod
                );
            }

            uint256 ourAllowance = USDTInterface.allowance(
                _msgSender(),
                address(this)
            );
            require(usdPrice <= ourAllowance, "Make sure to add enough allowance");
            (bool success, ) = address(USDTInterface).call(
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    _msgSender(),
                    address(this),
                    usdPrice
                )
            );
            require(success, "Token payment failed");
            emit TokensBought(
                _msgSender(),
                _id,
                address(USDTInterface),
                amount,
                usdPrice,
                block.timestamp
            );
            return true;
        }

        // Phase 2 is active. Everyone can buy
        else if (block.timestamp > presale[_id].startTimePhase2 && block.timestamp < presale[_id].endTimePhase2) {
            require(isWhitelisted(_id, msg.sender), "Not whitelisted");
            if (userVesting[_msgSender()][_id].totalAmount > 0) {
                userVesting[_msgSender()][_id].totalAmount += (amount *
                    _presale.baseDecimals);
            } else {
                userVesting[_msgSender()][_id] = Vesting(
                    (amount * _presale.baseDecimals),
                    0,
                    _presale.vestingStartTime + _presale.vestingCliff,
                    _presale.vestingStartTime +
                        _presale.vestingCliff +
                        _presale.vestingPeriod
                );
            }

            uint256 ourAllowance = USDTInterface.allowance(
                _msgSender(),
                address(this)
            );
            require(usdPrice <= ourAllowance, "Make sure to add enough allowance");
            (bool success, ) = address(USDTInterface).call(
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    _msgSender(),
                    address(this),
                    usdPrice
                )
            );
            require(success, "Token payment failed");
            emit TokensBought(
                _msgSender(),
                _id,
                address(USDTInterface),
                amount,
                usdPrice,
                block.timestamp
            );
            return true;
        } 
        // Phase 1 and Phase 2 are not active
        else {
            return false;
        }
    }

    /**
     * @dev To buy into a presale using ETH
     * @param _id Presale id
     * @param amount No of tokens to buy
     */
    function buyWithEth(uint256 _id, uint256 amount)
        external
        payable
        checkPresaleId(_id)
        checkSaleState(_id, amount)
        nonReentrant
        returns (bool)
    {
        require(amount <= presale[_id].maxAmountTokensForSalePerUser, "You are trying to buy too many tokens");
        require(!paused[_id], "Presale paused");
        require(presale[_id].enableBuyWithEth > 0, "Not allowed to buy with ETH");
        uint256 usdPrice = amount * presale[_id].price;
        uint256 ethAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
        require(msg.value >= ethAmount, "Less payment");
        uint256 excess = msg.value - ethAmount;
        presale[_id].inSale -= amount;
        Presale memory _presale = presale[_id];

        // Phase 1 is active and Phase 2 did not start yet. Whitelist required
        if (block.timestamp > presale[_id].startTimePhase1 && block.timestamp < presale[_id].startTimePhase2) {
            require(isWhitelisted(_id, msg.sender), "Not whitelisted");
            if (userVesting[_msgSender()][_id].totalAmount > 0) {
            userVesting[_msgSender()][_id].totalAmount += (amount *
                _presale.baseDecimals);
            } else {
                userVesting[_msgSender()][_id] = Vesting(
                    (amount * _presale.baseDecimals),
                    0,
                    _presale.vestingStartTime + _presale.vestingCliff,
                    _presale.vestingStartTime +
                        _presale.vestingCliff +
                        _presale.vestingPeriod
                );
            }
            sendValue(payable(address(this)), ethAmount);
            if (excess > 0) sendValue(payable(_msgSender()), excess);
            emit TokensBought(
                _msgSender(),
                _id,
                address(0),
                amount,
                ethAmount,
                block.timestamp
            );
            return true;
        }

        // Phase 2 is active. Everyone can buy
        else if (block.timestamp > presale[_id].startTimePhase2 && block.timestamp < presale[_id].endTimePhase2) {
            if (userVesting[_msgSender()][_id].totalAmount > 0) {
            userVesting[_msgSender()][_id].totalAmount += (amount *
                _presale.baseDecimals);
            } else {
                userVesting[_msgSender()][_id] = Vesting(
                    (amount * _presale.baseDecimals),
                    0,
                    _presale.vestingStartTime + _presale.vestingCliff,
                    _presale.vestingStartTime +
                        _presale.vestingCliff +
                        _presale.vestingPeriod
                );
            }
        sendValue(payable(address(this)), ethAmount);
        if (excess > 0) sendValue(payable(_msgSender()), excess);
        emit TokensBought(
            _msgSender(),
            _id,
            address(0),
            amount,
            ethAmount,
            block.timestamp
        );
        return true;
        } 
        // Phase 1 and Phase 2 are not active
        else {
            return false;
        }

        
    }

    /**
     * @dev Helper funtion to get ETH price for given amount
     * @param _id Presale id
     * @param amount No of tokens to buy
     */
    function ethBuyHelper(uint256 _id, uint256 amount)
        external
        view
        checkPresaleId(_id)
        returns (uint256 ethAmount)
    {
        uint256 usdPrice = amount * presale[_id].price;
        ethAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
    }

    /**
     * @dev Helper funtion to get USDT price for given amount
     * @param _id Presale id
     * @param amount No of tokens to buy
     */
    function usdtBuyHelper(uint256 _id, uint256 amount)
        external
        view
        checkPresaleId(_id)
        returns (uint256 usdPrice)
    {
        usdPrice = amount * presale[_id].price;
        usdPrice = usdPrice / (10**12);
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
        require(presale[_id].presaleFinalized == true, "Liquidity has not been added yet");
        require(amount > 0, "Zero claim amount");
        require(
            presale[_id].saleToken != address(0),
            "Presale token address not set"
        );
        require(
            amount <=
                IERC20Upgradeable(presale[_id].saleToken).balanceOf(
                    address(this)
                ),
            "Not enough tokens in the contract"
        );
        userVesting[user][_id].claimedAmount += amount;
        bool status = IERC20Upgradeable(presale[_id].saleToken).transfer(
            user,
            amount
        );
        require(status, "Token transfer failed");
        emit TokensClaimed(user, _id, amount, block.timestamp);
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
        require(presale[_id].presaleFinalized == true, "Liquidity has not been added yet");
        require(users.length > 0, "Zero users length");
        for (uint256 i; i < users.length; i++) {
            require(claim(users[i], _id), "Claim failed");
        }
        return true;
    }
}