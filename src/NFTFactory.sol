//SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFTFactory is ERC721URIStorage {
    error NotInheritanceManager();

    uint256 counter = 0;
    address inheritanceManager;

    constructor(address _inheritanceManager) ERC721("On Chain Estate", "OCE") {
        inheritanceManager = _inheritanceManager;
    }

    modifier onlyInheritanceManager() {
        if (msg.sender != inheritanceManager) {
            revert NotInheritanceManager();
        }
        _;
    }

    function createEstate(string memory description) external onlyInheritanceManager returns (uint256 itemID) {
        uint256 ID = _incrementCounter();
        _mint(msg.sender, ID);
        _setTokenURI(ID, description);
        return ID;
    }

    function burnEstate(uint256 _id) external onlyInheritanceManager {
        _burn(_id);
    }

    function _incrementCounter() internal returns (uint256) {
        return counter += 1;
    }
}
