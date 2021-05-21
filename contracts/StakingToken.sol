// SPDX-License-Identifier: -- 🦉 % 🥞 --

pragma solidity =0.7.5;

import "./ReferralToken.sol";

abstract contract StakingToken is ReferralToken {

    using SafeMath for uint256;

    /**
     * @notice A method for a staker to create multiple stakes
     * @param _stakedAmount amount of WISE staked.
     * @param _lockDays amount of days it is locked for.
     * @param _referrer address of the referrer
     */
    function createStakeBulk(
        uint256[] memory _stakedAmount,
        uint64[] memory _lockDays,
        address[] memory _referrer
    )
        external
    {
        for(uint256 i = 0; i < _stakedAmount.length; i++) {
            createStake(
                _stakedAmount[i],
                _lockDays[i],
                _referrer[i]
            );
        }
    }

    /**
     * @notice A method for a staker to create a stake
     * @param _stakedAmount amount of WISE staked.
     * @param _lockDays amount of days it is locked for.
     * @param _referrer address of the referrer
     */
    function createStake(
        uint256 _stakedAmount,
        uint64 _lockDays,
        address _referrer
    )
        snapshotTrigger
        public
        returns (bytes16, uint256, bytes16 referralID)
    {
        require(
            msg.sender != _referrer &&
            notContract(_referrer)
            // 'WISE: invalid referrer'
        );

        require(
            _lockDays >= MIN_LOCK_DAYS &&
            _lockDays <= MAX_LOCK_DAYS
            // 'WISE: stake is not in range'
        );

        require(
            _stakedAmount >= MIN_STAKE_AMOUNT
            // 'WISE: stake is not large enough'
        );

        (
            Stake memory newStake,
            bytes16 stakeID,
            uint256 _startDay
        ) =

        _createStake(msg.sender, _stakedAmount, _lockDays, _referrer);

        if (newStake.referrerShares > 0) {

            ReferrerLink memory referrerLink;

            referrerLink.staker = msg.sender;
            referrerLink.stakeID = stakeID;
            referrerLink.isActive = true;

            referralID = generateReferralID(_referrer);
            referrerLinks[_referrer][referralID] = referrerLink;

            _increaseReferralCount(
                _referrer
            );

            _addReferrerSharesToEnd(
                newStake.finalDay,
                newStake.referrerShares
            );
        }

        stakes[msg.sender][stakeID] = newStake;

        _increaseStakeCount(
            msg.sender
        );

        _increaseGlobals(
            newStake.stakedAmount,
            newStake.stakesShares,
            newStake.referrerShares
        );

        _addScheduledShares(
            newStake.finalDay,
            newStake.stakesShares
        );

        emit StakeStart(
            stakeID,
            msg.sender,
            _referrer,
            newStake.stakedAmount,
            newStake.stakesShares,
            newStake.referrerShares,
            newStake.startDay,
            newStake.lockDays,
            newStake.daiEquivalent
        );

        return (stakeID, _startDay, referralID);
    }

    /**
    * @notice A method for a staker to start a stake
    * @param _staker ...
    * @param _stakedAmount ...
    * @param _lockDays ...
    */
    function _createStake(
        address _staker,
        uint256 _stakedAmount,
        uint64 _lockDays,
        address _referrer
    )
        private
        returns (
            Stake memory _newStake,
            bytes16 _stakeID,
            uint64 _startDay
        )
    {
        _burn(
            _staker,
            _stakedAmount
        );

        _startDay = _nextWiseDay();
        _stakeID = generateStakeID(_staker);

        _newStake.lockDays = _lockDays;
        _newStake.startDay = _startDay;
        _newStake.finalDay = _startDay + _lockDays;
        _newStake.isActive = true;

        _newStake.stakedAmount = _stakedAmount;
        _newStake.stakesShares = _stakesShares(
            _stakedAmount,
            _lockDays,
            _referrer,
            globals.sharePrice
        );

        _newStake.daiEquivalent = _getBUSDEquivalent()
            .mul(_newStake.stakedAmount)
            .div(YODAS_PER_WISE);

        if (_nonZeroAddress(_referrer)) {

            _newStake.referrer = _referrer;

            _addCriticalMass(
                _newStake.referrer,
                _newStake.daiEquivalent
            );

            _newStake.referrerShares = _referrerShares(
                _stakedAmount,
                _lockDays,
                _referrer
            );
        }
    }

    /**
    * @notice A method for a staker to remove a stake
    * belonging to his address by providing ID of a stake.
    * @param _stakeID unique bytes sequence reference to the stake
    */
    function endStake(
        bytes16 _stakeID
    )
        snapshotTrigger
        external
        returns (uint256)
    {
        (
            Stake memory endedStake,
            uint256 penaltyAmount
        ) =

        _endStake(
            msg.sender,
            _stakeID
        );

        _decreaseGlobals(
            endedStake.stakedAmount,
            endedStake.stakesShares,
            endedStake.referrerShares
        );

        _removeScheduledShares(
            endedStake.finalDay,
            endedStake.stakesShares
        );

        _removeReferrerSharesToEnd(
            endedStake.finalDay,
            endedStake.referrerShares
        );

        _removeCriticalMass(
            endedStake.referrer,
            endedStake.daiEquivalent,
            endedStake.startDay
        );

        _storePenalty(
            endedStake.closeDay,
            penaltyAmount
        );

        _sharePriceUpdate(
            endedStake.stakedAmount > penaltyAmount ?
            endedStake.stakedAmount - penaltyAmount : 0,
            endedStake.rewardAmount + scrapes[msg.sender][_stakeID],
            endedStake.referrer,
            endedStake.lockDays,
            endedStake.stakesShares
        );

        emit StakeEnd(
            _stakeID,
            msg.sender,
            endedStake.referrer,
            endedStake.stakedAmount,
            endedStake.stakesShares,
            endedStake.referrerShares,
            endedStake.rewardAmount,
            endedStake.closeDay,
            penaltyAmount
        );

        return endedStake.rewardAmount;
    }

    function _endStake(
        address _staker,
        bytes16 _stakeID
    )
        private
        returns (
            Stake storage _stake,
            uint256 _penalty
        )
    {
        require(
            stakes[_staker][_stakeID].isActive
            // 'WISE: not an active stake'
        );

        _stake = stakes[_staker][_stakeID];
        _stake.closeDay = _currentWiseDay();
        _stake.rewardAmount = _calculateRewardAmount(_stake);
        _penalty = _calculatePenaltyAmount(_stake);

        _stake.isActive = false;

        _mint(
            _staker,
            _stake.stakedAmount > _penalty ?
            _stake.stakedAmount - _penalty : 0
        );

        _mint(
            _staker,
            _stake.rewardAmount
        );
    }

    /**
    * @notice alloes to scrape interest from active stake
    * @param _stakeID unique bytes sequence reference to the stake
    * @param _scrapeDays amount of days to proccess, 0 = all
    */
    function scrapeInterest(
        bytes16 _stakeID,
        uint64 _scrapeDays
    )
        external
        snapshotTrigger
        returns (
            uint256 scrapeDay,
            uint256 scrapeAmount,
            uint256 remainingDays,
            uint256 stakersPenalty,
            uint256 referrerPenalty
        )
    {
        require(
            stakes[msg.sender][_stakeID].isActive
            // 'WISE: not an active stake'
        );

        Stake memory stake = stakes[msg.sender][_stakeID];

        scrapeDay = _scrapeDays > 0
            ? _startingDay(stake).add(_scrapeDays)
            : _calculationDay(stake);

        scrapeDay = scrapeDay > stake.finalDay
            ? _calculationDay(stake)
            : scrapeDay;

        scrapeAmount = _loopRewardAmount(
            stake.stakesShares,
            _startingDay(stake),
            scrapeDay
        );

        if (_isMatureStake(stake) == false) {

            remainingDays = _daysLeft(stake);

            stakersPenalty = _stakesShares(
                scrapeAmount,
                remainingDays,
                msg.sender,
                globals.sharePrice
            );

            stake.stakesShares =
            stake.stakesShares.sub(stakersPenalty);

            _removeScheduledShares(
                stake.finalDay,
                stakersPenalty
            );

            if (stake.referrerShares > 0) {

                referrerPenalty = _stakesShares(
                    scrapeAmount,
                    remainingDays,
                    address(0x0),
                    globals.sharePrice
                );

                stake.referrerShares =
                stake.referrerShares.sub(referrerPenalty);

                _removeReferrerSharesToEnd(
                    stake.finalDay,
                    referrerPenalty
                );
            }

            _decreaseGlobals(
                0,
                stakersPenalty,
                referrerPenalty
            );

            _sharePriceUpdate(
                stake.stakedAmount,
                scrapeAmount,
                stake.referrer,
                stake.lockDays,
                stake.stakesShares
            );
        }
        else {
            scrapes[msg.sender][_stakeID] =
            scrapes[msg.sender][_stakeID].add(scrapeAmount);

            _sharePriceUpdate(
                stake.stakedAmount,
                scrapes[msg.sender][_stakeID],
                stake.referrer,
                stake.lockDays,
                stake.stakesShares
            );
        }

        stake.scrapeDay = scrapeDay;
        stakes[msg.sender][_stakeID] = stake;

        _mint(
            msg.sender,
            scrapeAmount
        );

        emit InterestScraped(
            _stakeID,
            msg.sender,
            scrapeAmount,
            scrapeDay,
            stakersPenalty,
            referrerPenalty,
            _currentWiseDay()
        );
    }

    function _addScheduledShares(
        uint256 _finalDay,
        uint256 _shares
    )
        internal
    {
        scheduledToEnd[_finalDay] =
        scheduledToEnd[_finalDay].add(_shares);
    }

    function _removeScheduledShares(
        uint256 _finalDay,
        uint256 _shares
    )
        internal
    {
        if (_notPast(_finalDay)) {

            scheduledToEnd[_finalDay] =
            scheduledToEnd[_finalDay] > _shares ?
            scheduledToEnd[_finalDay] - _shares : 0;

        } else {

            uint256 _day = _previousWiseDay();
            snapshots[_day].scheduledToEnd =
            snapshots[_day].scheduledToEnd > _shares ?
            snapshots[_day].scheduledToEnd - _shares : 0;
        }
    }

    function _sharePriceUpdate(
        uint256 _stakedAmount,
        uint256 _rewardAmount,
        address _referrer,
        uint256 _lockDays,
        uint256 _stakeShares
    )
        private
    {
        if (_stakeShares > 0 && _currentWiseDay() > FORMULA_DAY) {

            uint256 newSharePrice = _getNewSharePrice(
                _stakedAmount,
                _rewardAmount,
                _stakeShares,
                _lockDays,
                _referrer
            );

            if (newSharePrice > globals.sharePrice) {

                newSharePrice =
                    newSharePrice < globals.sharePrice.mul(110).div(100) ?
                    newSharePrice : globals.sharePrice.mul(110).div(100);

                emit NewSharePrice(
                    newSharePrice,
                    globals.sharePrice,
                    _currentWiseDay()
                );

                globals.sharePrice = newSharePrice;
            }

            return;
        }

        if (_currentWiseDay() == FORMULA_DAY) {
            globals.sharePrice = 110E15;
        }
    }

    function _getNewSharePrice(
        uint256 _stakedAmount,
        uint256 _rewardAmount,
        uint256 _stakeShares,
        uint256 _lockDays,
        address _referrer
    )
        private
        pure
        returns (uint256)
    {

        uint256 _bonusAmount = _getBonus(
            _lockDays, _nonZeroAddress(_referrer) ? 11E9 : 10E9
        );

        return
            _stakedAmount
                .add(_rewardAmount)
                .mul(_bonusAmount)
                .mul(1E8)
                .div(_stakeShares);
    }

    function checkMatureStake(
        address _staker,
        bytes16 _stakeID
    )
        external
        view
        returns (bool isMature)
    {
        Stake memory stake = stakes[_staker][_stakeID];
        isMature = _isMatureStake(stake);
    }

    function checkStakeByID(
        address _staker,
        bytes16 _stakeID
    )
        external
        view
        returns (
            uint256 startDay,
            uint256 lockDays,
            uint256 finalDay,
            uint256 closeDay,
            uint256 scrapeDay,
            uint256 stakedAmount,
            uint256 stakesShares,
            uint256 rewardAmount,
            uint256 penaltyAmount,
            bool isActive,
            bool isMature
        )
    {
        Stake memory stake = stakes[_staker][_stakeID];
        startDay = stake.startDay;
        lockDays = stake.lockDays;
        finalDay = stake.finalDay;
        closeDay = stake.closeDay;
        scrapeDay = stake.scrapeDay;
        stakedAmount = stake.stakedAmount;
        stakesShares = stake.stakesShares;
        rewardAmount = _checkRewardAmount(stake);
        penaltyAmount = _calculatePenaltyAmount(stake);
        isActive = stake.isActive;
        isMature = _isMatureStake(stake);
    }

    function _stakesShares(
        uint256 _stakedAmount,
        uint256 _lockDays,
        address _referrer,
        uint256 _sharePrice
    )
        private
        pure
        returns (uint256)
    {
        return _nonZeroAddress(_referrer)
            ? _sharesAmount(_stakedAmount, _lockDays, _sharePrice, 11E9)
            : _sharesAmount(_stakedAmount, _lockDays, _sharePrice, 10E9);
    }

    function _sharesAmount(
        uint256 _stakedAmount,
        uint256 _lockDays,
        uint256 _sharePrice,
        uint256 _extraBonus
    )
        private
        pure
        returns (uint256)
    {
        return _baseAmount(_stakedAmount, _sharePrice)
            .mul(_getBonus(_lockDays, _extraBonus))
            .div(10E9);
    }

    function _getBonus(
        uint256 _lockDays,
        uint256 _extraBonus
    )
        private
        pure
        returns (uint256)
    {
        return
            _regularBonus(_lockDays, DAILY_BONUS_A, MAX_BONUS_DAYS_A) +
            _regularBonus(
                _lockDays > MAX_BONUS_DAYS_A ?
                _lockDays - MAX_BONUS_DAYS_A : 0, DAILY_BONUS_B, MAX_BONUS_DAYS_B
            ) + _extraBonus;
    }

    function _regularBonus(
        uint256 _lockDays,
        uint256 _daily,
        uint256 _maxDays
    )
        private
        pure
        returns (uint256)
    {
        return (
            _lockDays > _maxDays
                ? _maxDays.mul(_daily)
                : _lockDays.mul(_daily)
            ).div(10E9);
    }

    function _baseAmount(
        uint256 _stakedAmount,
        uint256 _sharePrice
    )
        private
        pure
        returns (uint256)
    {
        return
            _stakedAmount
                .mul(PRECISION_RATE)
                .div(_sharePrice);
    }

    function _referrerShares(
        uint256 _stakedAmount,
        uint256 _lockDays,
        address _referrer
    )
        private
        view
        returns (uint256)
    {
        return
            _notCriticalMassReferrer(_referrer) ||
            _lockDays < MIN_REFERRAL_DAYS
                ? 0
                : _sharesAmount(
                    _stakedAmount,
                    _lockDays,
                    globals.sharePrice,
                    10E9
                );
    }

    function _checkRewardAmount(Stake memory _stake) private view returns (uint256) {
        return _stake.isActive ? _detectReward(_stake) : _stake.rewardAmount;
    }

    function _detectReward(Stake memory _stake) private view returns (uint256) {
        return _stakeNotStarted(_stake) ? 0 : _calculateRewardAmount(_stake);
    }

    function _storePenalty(
        uint64 _storeDay,
        uint256 _penalty
    )
        private
    {
        if (_penalty > 0) {
            totalPenalties[_storeDay] =
            totalPenalties[_storeDay].add(_penalty);
        }
    }

    function _calculatePenaltyAmount(
        Stake memory _stake
    )
        private
        view
        returns (uint256)
    {
        return _stakeNotStarted(_stake) || _isMatureStake(_stake) ? 0 : _getPenalties(_stake);
    }

    function _getPenalties(Stake memory _stake)
        private
        view
        returns (uint256)
    {
        return _stake.stakedAmount * (100 + (800 * (_daysLeft(_stake) - 1) / (_getLockDays(_stake)))) / 1000;
    }

    function _calculateRewardAmount(
        Stake memory _stake
    )
        private
        view
        returns (uint256)
    {
        return _loopRewardAmount(
            _stake.stakesShares,
            _startingDay(_stake),
            _calculationDay(_stake)
        );
    }

    function _loopRewardAmount(
        uint256 _stakeShares,
        uint256 _startDay,
        uint256 _finalDay
    )
        private
        view
        returns (uint256 _rewardAmount)
    {
        for (uint256 _day = _startDay; _day < _finalDay; _day++) {
            _rewardAmount += _stakeShares * PRECISION_RATE / snapshots[_day].inflationAmount;
        }
    }
}
