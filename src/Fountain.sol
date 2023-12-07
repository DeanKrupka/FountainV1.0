//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
//import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

error Fountain__NotOwner();
error Fountain__ValueMustBeGreaterThanZero();

contract Fountain is IERC721Receiver, Ownable {
    event TossedEthOrToken(
        address indexed _from,
        uint256 _value,
        address _tokenAddress
    );

    event TossedNft(
        address indexed _from,
        address _nftContract,
        uint256 _tokenId
    );

    address private immutable i_owner;
    address[] private s_tossers;
    address[] private s_tokenAddresses;
    address[] private s_nftTossers;

    struct TosserAddressAndAmount {
        /* AKA Tosses */
        address tosserAddress;
        uint256 amount;
    }

    mapping(address => TosserAddressAndAmount[]) private tokenAddressToTosses;
    mapping(address => uint256) private tokenAddressToTotalTossed;

    constructor() Ownable(msg.sender) {
        i_owner = msg.sender;
        s_tokenAddresses.push(address(0)); // initializes first element of array for Eth
    }

    function tossEth() public payable {
        //Toss - Perform Transfer
        if (msg.value == 0) revert Fountain__ValueMustBeGreaterThanZero();

        //Accounting of Toss
        s_tossers.push(msg.sender);
        tokenAddressToTosses[address(0)].push(
            TosserAddressAndAmount(msg.sender, msg.value)
        );
        tokenAddressToTotalTossed[address(0)] += msg.value;

        emit TossedEthOrToken(msg.sender, msg.value, address(0));
    }

    function approveTossToken(address _tokenAddress, uint256 _value) public {
        bool approveToss = ERC20(_tokenAddress).approve(address(this), _value);
        require(approveToss, "ERC20 Approval failed.");
    }

    function tossToken(address _tokenAddress, uint256 _value) public {
        //Toss - Perform Transfer
        if (_value == 0) revert Fountain__ValueMustBeGreaterThanZero();
        bool transferSuccess = ERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _value
        );
        require(transferSuccess, "ERC20 Toss failed.");

        //Accounting of Tosses
        s_tossers.push(msg.sender);
        s_tokenAddresses.push(_tokenAddress);
        tokenAddressToTosses[_tokenAddress].push(
            TosserAddressAndAmount(msg.sender, _value)
        );
        tokenAddressToTotalTossed[_tokenAddress] += _value;

        emit TossedEthOrToken(msg.sender, _value, _tokenAddress);
    }

    function tossNfts(
        address[] calldata _nftContracts,
        uint256[] calldata _tokenIds
    ) external {
        require(
            _nftContracts.length == _tokenIds.length,
            "Arrays must be same length"
        );
        for (uint256 i = 0; i < _nftContracts.length; i++) {
            //Toss - Perform Transfer
            IERC721(_nftContracts[i]).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
            //Accounting of Tosses
            emit TossedNft(msg.sender, _nftContracts[i], _tokenIds[i]);
        }
        s_nftTossers.push(msg.sender);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function withdrawEth() public onlyOwner {
        (bool callSuccess, ) = payable(i_owner).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    fallback() external payable {
        tossEth();
    }

    receive() external payable {
        tossEth();
    }

    ///// Getters /////

    function getTossers(uint256 _addressIndex) public view returns (address) {
        return s_tossers[_addressIndex];
    }

    function getTokenAddresses(
        uint256 _addressIndex
    ) public view returns (address) {
        return s_tokenAddresses[_addressIndex];
    }

    function getTotalTossedByTokenAddress(
        uint256 _addressIndex
    ) public view returns (uint256) {
        return tokenAddressToTotalTossed[s_tokenAddresses[_addressIndex]];
    }

    function getTossesByTokenAddress(
        address tokenAddress
    ) public view returns (TosserAddressAndAmount[] memory) {
        return tokenAddressToTosses[tokenAddress];
    }
}
