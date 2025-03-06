//SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

abstract contract Trustee {
    error NotTrustee(address);

    address trustee;
    address assetToPay;

    mapping(uint256 NftIndex => uint256 value) nftValue;

    modifier onlyTrustee() {
        if (msg.sender != trustee) {
            revert NotTrustee(msg.sender);
        }
        _;
    }

    function setNftValue(uint256 _index, uint256 _value) public onlyTrustee {
        nftValue[_index] = _value;
    }

    function setAssetToPay(address _asset) external onlyTrustee {
        assetToPay = _asset;
    }

    function getNftValue(uint256 _id) public view returns (uint256) {
        return nftValue[_id];
    }

    function getAssetToPay() public view returns (address) {
        return assetToPay;
    }
}
