pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract CryptofieldBase {
    using SafeMath for uint256;

    uint256 private saleId;

    bytes32 private lastSex = "F"; // First horse is a male.

    /*
    @dev horseHash stores basic horse information in a hash returned by IPFS.
    */
    struct Horse {
        address buyer;

        uint256 saleId;
        uint256 timestamp;
        uint256 reserveValue;
        uint256 saleValue;
        uint256 feeValue;
        uint256 dateSold;
        uint256 amountOfTimesSold;

        // Check if we can use bytes32[] instead of uint8[] to store foal names.
        uint8[] foalNames;
        uint8[] parents;
        uint8[] grandparents;
        uint8[] greatgrandparents;

        uint256[7] characteristics;

        string previousOwner;
        string horseHash;
        string sex;

        // Rank is based on awards.
        bytes32 rank;

    }

    mapping(uint256 => Horse) public horses;

    event HorseSell(uint256 _horseId, uint256 _amountOfTimesSold);
    event HorseBuy(address _buyer, uint256 _timestamp, uint256 _saleId);

    function buyHorse(address _buyer, string _horseHash, uint256 _tokenId) public {
        saleId = saleId.add(1);

        Horse memory horse;
        horse.buyer = _buyer;
        horse.saleId = saleId;
        // The use of 'now' here shouldn't be a concern since that's only used for the timestamp of a horse
        // which really doesn't have much effect on the horse itself.
        horse.timestamp = now;
        horse.horseHash = _horseHash;
        horse.sex = (lastSex == "M" ? "F" : "M");
        horse.characteristics = _genCharacteristics();

        if(lastSex == "M") {lastSex = "F";} else {lastSex = "M";}

        horses[_tokenId] = horse;

        emit HorseBuy(_buyer, now, horse.saleId);
    }

    /*
    @dev Only returns the hash containing basic information of horse (name, color, origin, etc...)
    @param _horseId Token of the ID to retrieve hash from.
    @returns string, IPFS hash
    */

    function getHorse(uint256 _horseId) public view returns(string) {
        Horse memory horse = horses[_horseId];

        return (horse.horseHash);
    }

    /*
    @dev Returns sex of horse.
    */
    function getHorseSex(uint256 _horseId) public view returns(string) {
        Horse memory h = horses[_horseId];
        return h.sex;
    }

    /*
    @dev We can use the above functions independiently or get the whole family data from this function
    @returns all the information with from a horse's family (Foal names, parents, grandparents and
        great-grandparents)
    */
    function getHorseFamily(uint256 _horseId) public view returns(uint8[], uint8[], uint8[], uint8[]) {
        Horse memory h = horses[_horseId];
        return (h.foalNames, h.parents, h.grandparents, h.greatgrandparents);
    }

    /*
    @returns all the information related to auction of a horse
    */
    function horseAuctionInformation(uint256 _horseId) public view returns(uint256, uint256, uint256, uint256) {

        Horse memory horse = horses[_horseId];

        return (horse.reserveValue, horse.saleValue, horse.feeValue, horse.amountOfTimesSold);
    }

    /*
    @dev Adds 1 to the amount of times a horse has been sold.
    @dev Adds unix timestamp of the date the horse was sold.
    */

    //TODO: Add modifier in this function
    function horseSold(uint256 _horseId) public {
        Horse storage horse = horses[_horseId];
        horse.amountOfTimesSold = horse.amountOfTimesSold.add(1);
        horse.dateSold = now;

        emit HorseSell(_horseId, horse.amountOfTimesSold);
    }

    function getTimestamp(uint256 _horseId) public view returns(uint256) {
        return horses[_horseId].timestamp;
    }

    /* PRIVATE FUNCTIONS */

    /*
    @dev Generates random values for characteristics, each number represents a characteristic.
    */
    function _genCharacteristics() private returns(uint256[7]) {
        uint256 hType = _getRand(2);
        uint256 height = _getRand(3);
        uint256 running = _getRand(21);
        uint256 uniqCh = _getRand(555);
        uint256 origin = _getRand(3); // TODO: May change.
        uint256 pedigree = _getRand(5);
        uint256 color = _getRand(19);

        uint256[7] memory chars = [hType, height, running, uniqCh, origin, pedigree, color];

        return chars;
    }

    function _getRand(uint max) private view returns(uint) {
        return uint(blockhash(block.number - 1)) % max + 1;
    }
}
