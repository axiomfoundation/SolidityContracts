pragma solidity ^0.4.18;

import "./ERC20.sol";

contract ReviewerGroup {
    mapping(address => bool) public isOwner;
    mapping(address => bool) public isReviewer;
    
    event NewArticle(
        ReviewArticle articleAddress
    );

    function ReviewerGroup () public {
        isOwner[msg.sender] = true;
        isReviewer[msg.sender] = true;
    }
    
    modifier ownerAccess {
        require(isOwner[msg.sender]);
        _;
    }
    
    function changeOwner(address _ownerAddress, bool _newState) ownerAccess public {
        isOwner[_ownerAddress] = _newState;
    }
    
    function changeReviewer(address _reviewerAddress, bool _newState) ownerAccess public {
        isReviewer[_reviewerAddress] = _newState;
    }
    
    function reportNewArticle (ReviewArticle _article) public {
        emit NewArticle(_article); //someone will have to check it's not a malitious contract!
    }
}


contract ReviewArticle {
    string public title;
    string public authors;
    uint public timestamp;
    string public meta; // link to ipfs article Json - Affiliations, Abstract, searchable values etc...
    string public pdf; // link to ipfs article
    address public author;

    function ReviewArticle(string _meta, string _pdf, string _title, string _authors) public {
        meta = _meta;
        pdf = _pdf;
        title = _title;
        authors = _authors;
        timestamp = now;
        author = msg.sender;
    }

    TokenERC20 public _ScienceToken;
    ReviewerGroup public reviewerGroup;
    uint public bounty;
    mapping (address => bool) hasReviewed;
    string[] public reviewsMeta;
    address[] public reviewers;
    
    uint reviewCount = 0;
    
    modifier authorAccess {
        require(msg.sender == author);
        _;
    } 
    
    modifier reviewerAccess {
        require(reviewerGroup.isReviewer(msg.sender));
        _;
    }
    
    // always make sure you paid to the article address beforehand.
    // this function can be called once
    function approveReviewers (ReviewerGroup _reviewerGroup, uint _numberReviews, TokenERC20 _tokenAddress) authorAccess public {
        require(reviewerGroup == address(0));
        _ScienceToken = TokenERC20(_tokenAddress);
        uint totalBounty = _ScienceToken.balanceOf(this);
        require(totalBounty > 0);
        reviewerGroup = _reviewerGroup;
        bounty = totalBounty / _numberReviews;  //rounded down. there will be 0 or some fraction left at the end which is ok.
        reviewerGroup.reportNewArticle(this);
    }
    
    function addReview (string _reviewMeta) reviewerAccess public{
        require(_ScienceToken.balanceOf(this) >= bounty);
        require(reviewerGroup.isReviewer(msg.sender));
        require(!hasReviewed[msg.sender]);
        reviewsMeta.push(_reviewMeta);
        reviewers.push(msg.sender);
        reviewCount++;
        _ScienceToken.transfer(msg.sender, bounty);
    }
    
}