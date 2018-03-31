pragma solidity ^0.4.19;

import "./ERC20.sol";
import "./Article.sol";

contract Field {
    mapping(address => bool) public isReviewer;
    uint public fieldSize;
    string public fieldName;
    
    event NewArticle(
        address articleAddress
    );

    function Field (string _fieldName) public {
        isReviewer[msg.sender] = true;
        fieldName = _fieldName;
        fieldSize = 1;
    }
    
    function join() public {
        require(!isReviewer[msg.sender]);
        require(!isContract(msg.sender));
        isReviewer[msg.sender] = true;
        fieldSize++;        
    }
    
    function leave() public {
        require(isReviewer[msg.sender]);
        require(!isContract(msg.sender));
        isReviewer[msg.sender] = false;
        fieldSize--;
    }
    
    function isContract(address addr) private view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    
    function reportNewArticle () public {
        require(isContract(msg.sender));
        emit NewArticle(msg.sender); //someone will have to check it's not a malicious contract!
    }
}