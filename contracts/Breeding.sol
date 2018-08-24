pragma solidity 0.4.24;

import "./Core.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

// TODO: PROBABLY MOVING MOST OF THIS LOGIC TO ANOTHER CONTRACT

/*
@dev Breeding contract in charge of generating new horses and stats for breeding.
*/
contract Breeding is Ownable {
    using SafeMath for uint256;

    uint256 constant MALE_CAP = 240;
    uint256 constant FEMALE_CAP =  48;

    Core core;

    // All this is subject to a change
    struct HorseBreed {
        uint256[2] parentsId;

        uint256 firstOffspring;
        uint256 trackingNumber;
        uint256 raceCounter;
        uint256 offspringCounter;
        uint256 raceVariable;
        uint256 racePerfomance;
        uint256 raceOutcome;
        uint256 tieBreaker;
        uint256 oddValue;
        uint256 oddComparison;
        uint256 racesWon;
        uint256 racesLost;

        mapping(uint256 => uint256) lineages;
    }

    // Maps the horseID to a specific HorseBreed struct.
    mapping(uint256 => HorseBreed) internal horseBreedById;

    event OffspringCreated(uint256 _father, uint256 _mother, uint256 _offspring);

    constructor(address _core) public {
        core = Core(_core);
        owner = msg.sender;
    }

    /*
    @dev Creates a new token based on parents.
    */
    function mix(uint256 _maleParent, uint256 _femaleParent, string _hash) external {
        // The offspring belongs to the owner of the female horse.
        address offspringOwner = core.ownerOf(_femaleParent);

        HorseBreed storage male = horseBreedById[_maleParent];
        HorseBreed storage female = horseBreedById[_femaleParent];

        // Since this means that it is the first offspring of either one, we get their timestamp here and use
        // it as their tracking number.
        if(female.firstOffspring == 0) {
            female.trackingNumber = core.getTimestamp(_femaleParent).div(_getRandNum());
            female.firstOffspring = now;
        }
 
        if(male.firstOffspring == 0) {
            male.trackingNumber = core.getTimestamp(_maleParent).mul(_getRandNum());
            male.firstOffspring = now;
        }

        // Male horse should be in Stud so the owner of the female should send this transaction.
        require(msg.sender == offspringOwner, "Not owner of female horse");
        // require(_canBreed(_getMaleParentLineage(male), _getFemaleParentLineage(female)), "Lineages collide");
        require(_canBreed(_maleParent, _femaleParent), "Lineages collide");
        require(_checkGenders(_maleParent, _femaleParent), "Genders are the same");

        uint256 tokenId = core.createOffspring(offspringOwner, _hash, _maleParent, _femaleParent);

        male.offspringCounter = male.offspringCounter.add(1);
        female.offspringCounter = female.offspringCounter.add(1);

        // Default is 0, the firstOffspring key needs to yield something else than 0 otherwise this
        // 'require' will never be met.
        require(_checkOffspringCounter(male, female), "Max cap reached");

        // Offspring data
        HorseBreed storage o = horseBreedById[tokenId];
        o.trackingNumber = _genTrackingNumber(tokenId);
        o.parentsId = [_maleParent, _femaleParent];
        o.lineages[1] = male.trackingNumber;
        o.lineages[2] = female.trackingNumber;
        o.lineages[3] = male.lineages[1];
        o.lineages[4] = male.lineages[2];
        o.lineages[5] = female.lineages[1];
        o.lineages[6] = female.lineages[2];

        core.setBaseValue(tokenId, _getBaseValue(_maleParent, _femaleParent));

        emit OffspringCreated(_maleParent, _femaleParent, tokenId);
    }

    /*
    Based on the lineages sent check if there is no coallison between them, i.e. one being equal to another.
    */
    function _canBreed(uint256 _male, uint256 _female) private view returns(bool) {
        HorseBreed storage male = horseBreedById[_male];
        HorseBreed storage female = horseBreedById[_female];

        for(uint256 i = 0; i < 2; i++) {
            for(uint256 j = 0; i < 2; i++) {
                if(male.lineages[i] == 0 || female.lineages[i] == 0) {
                    continue;
                } else {
                    if(male.lineages[i] == female.lineages[j]) return false;
                }
            }
        }

        return true;
    }

    /*
    @dev Checks whether the male or female parent have less than the max cap for offsprings for the year.
    We're going to check the amount of years that have gone by and multiply that by the max cap,
    and check if the horse has not met its maximum cap yet.
    */
    function _checkOffspringCounter(HorseBreed male, HorseBreed female) private returns(bool) {
        uint256 maleYears = now.sub(male.firstOffspring).div(365 days).add(1);
        uint256 maleCapAllowed = maleYears.mul(MALE_CAP); // Male Cap

        uint256 femaleYears = now.sub(female.firstOffspring).div(365 days).add(1);
        uint256 femaleCapAllowed = femaleYears.mul(FEMALE_CAP); // Female cap

        return male.offspringCounter <= maleCapAllowed || female.offspringCounter <= femaleCapAllowed;
    }

    /*
    @dev Check if the horses have the correct sex for breeding.
    */
    function _checkGenders(uint256 _first, uint256 _second) private view returns(bool) {
        bytes32 firstHorseSex = core.getHorseSex(_first);
        bytes32 secondHorseSex = core.getHorseSex(_second);

        return keccak256(abi.encodePacked(firstHorseSex)) != keccak256(abi.encodePacked(secondHorseSex));
    }

    /*
    @dev Gets a random number between 1 and 100, there are not security concerns here so we're using the
    block.blockhash and block.number.
    */
    function _getRandNum() private view returns(uint256) {
        return uint256(blockhash(block.number.sub(1))) % 100 + 1;
    }

    /*
    @dev Computes the base value for an offspring
    */
    function _getBaseValue(uint256 _maleParent, uint256 _femaleParent) private view returns(uint) {
        // Create the offspring baseValue
        uint256 percentageFromMale = _getRandNum();
        uint256 maleBaseValue = core.getBaseValue(_maleParent);
        uint256 maleValue = percentageFromMale.mul(maleBaseValue);
        uint256 finalMaleValue = maleValue.div(100);
        
        uint256 percentageFromFemale = 100 - percentageFromMale;
        uint256 femaleBaseValue = core.getBaseValue(_femaleParent);
        uint256 femaleValue = percentageFromFemale.mul(femaleBaseValue);
        uint256 finalFemaleValue = femaleValue.div(100);

        return finalMaleValue.add(finalFemaleValue);
    }

    /*
    @dev Generates a random tracking number based on the gender of the horse
    */
    function _genTrackingNumber(uint256 _horseId) private view returns(uint256) {
        bytes32 gender = core.getHorseSex(_horseId);

        if(gender == bytes32("M")) {
            return now.mul(_getRandNum());
        } else {
            return now.mul(_getRandNum());
        }
    }

    /*
    @dev Returns a given horse tracking number
    */
    function getTrackingNumber(uint256 _id) public view returns(uint256) {
        return horseBreedById[_id].trackingNumber;
    }

    /*
    @dev Returns a horse stats for breeding.
    */
    function getHorseOffspringStats(uint256 _horseId) public view returns(uint256, uint256) {
        HorseBreed memory h = horseBreedById[_horseId];
        return(h.offspringCounter, h.firstOffspring);
    }

    /*
    @dev Get lineages of a horse
    */
    function getLineage(uint256 _horseId) public view returns(uint256, uint256, uint256, uint256, uint256, uint256) {
        HorseBreed storage h = horseBreedById[_horseId];
        return(h.lineages[1], h.lineages[2], h.lineages[3], h.lineages[4], h.lineages[5], h.lineages[6]);
    }

    /*  RESTRICTED */

    function setCore(address _core) public onlyOwner() {
        core = Core(_core);
    }
}