pragma solidity ^0.4.18;

import "./ERC20.sol";

contract Journal {
    TokenERC20 _ScienceToken;
    
    mapping(address => bool) public isOwner;
    mapping(address => bool) public isEditor;
    mapping(address => bool) public isReviewer;
    mapping(address => bool) public isStaff;
    mapping(address => uint) public staffIndex;
    address[] public staff;
    uint public staffCount = 0;
    
    string public title; // Journal title: "Distributed Journal of Nanotechnologies...
    string public description; // Injected HTML from IPFS. Possibly css and shit
    uint public publicationCost = 0;
    
    mapping(address => bool) public isApprovedPublication;
    mapping(address => bool) public isPublished;
    mapping(address => uint) public articleIndex;
    Article[] public articles;
    uint public articleCount = 0; // to allow article deletion, keep index of the last

    
    modifier ownerAccess {
        require(isOwner[msg.sender]);
        _;
    }
    
    modifier editorAccess {
        require(isOwner[msg.sender] || isEditor[msg.sender]);
        _;
    }
 
    modifier reviewerAccess {
        require(isOwner[msg.sender] || isEditor[msg.sender] || isReviewer[msg.sender]);
        _;
    }
    
    function setStaff(address staffAddress, bool owner, bool editor, bool reviewer) private {
        isOwner[staffAddress] = owner;
        isEditor[staffAddress] = editor;
        isReviewer[staffAddress] = reviewer;
        if (!isStaff[staffAddress]) {
            isStaff[staffAddress] = true;
            if (staff.length > staffCount) {
                staff[staffCount] = staffAddress;
            } else {
                staff.push(staffAddress);
            }
            staffIndex[staffAddress] = staffCount;
            staffCount++;
        }
    }

    function setArticle(address articleAddress, address uploader) private {
        require (isApprovedPublication[articleAddress]); 
        Article article = Article(articleAddress);
        require (uploader == article.author());
        articles.push(article);
        articleIndex[article] = articleCount;
        articleCount++;
        isPublished[articleAddress] = true;
    }

    //contract
    function Journal(string _title, address tokenAddress) public {
        setStaff(msg.sender, true, true, true);
        title = _title;
         _ScienceToken = TokenERC20(tokenAddress);
    }

    // ownerAccess    
    function setOwner (address newAddress, bool status) ownerAccess public {
        setStaff(newAddress, status, isEditor[newAddress], isReviewer[newAddress]);
    }
    
    function setEditor (address newAddress, bool status) ownerAccess public {
        setStaff(newAddress, isOwner[newAddress], status, isReviewer[newAddress]);
    }
    
    function setDescription (string _description) ownerAccess public {
        description = _description;
    }


    function setPublicationCost (uint cost) ownerAccess public {
        publicationCost = cost;
    } 
    
    function setAllowance (address to, uint value) ownerAccess public {
        require(isOwner[to] || isEditor[to] || isReviewer[to]);
        _ScienceToken.approve(to, value);
    }

    function removeStaff(address staffAddress) ownerAccess public { //move last instead
        uint index = staffIndex[staffAddress];
        isStaff[staffAddress] = false;
        isOwner[staffAddress] = false;
        isEditor[staffAddress] = false;
        isReviewer[staffAddress] = false;
        staff[index] = staff[staffCount - 1];
        staffCount--;
    }
    
    function removeArticle (address articleAddress) ownerAccess public {
        uint index = articleIndex[articleAddress];
        isPublished[articles[index]] = false;
        delete articles[index]; //in case someone wants to delete unaprpriate submission
    }

    
    // editorAccess
    function setReviewer (address newAddress, bool status) editorAccess public {
        setStaff(newAddress, isOwner[newAddress], isEditor[newAddress], status);
    }
    

    function changePublicationStatus (address articleAddress, bool status) editorAccess public {
        isApprovedPublication[articleAddress] = status; //publish article
    }
    
    // public access
    function publishArticle (address articleAddress) public {
        if (publicationCost > 0) {
            //require (_ScienceToken.balanceOf(msg.sender) >= PublicationCost); //not needed, ERC20 will throw 
            _ScienceToken.transferFrom(msg.sender, this, publicationCost); //if one has approved beforehand
        }
        setArticle(articleAddress, msg.sender);
    }
    
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public { //don't call this if it's free to publish...
        require(_token == address(_ScienceToken));
        require(_token == msg.sender);
        require(_value >= publicationCost);
        require(_extraData.length == 20);
        address articleAddress;
        assembly 
        {
            let m := mload(0x80) //mem location of _extraData
            articleAddress := div(m,0x1000000000000000000000000) //shift it to start
        }
        _ScienceToken.transferFrom(_from, this, publicationCost);
        setArticle(articleAddress, _from);
    }
}

contract Article {
    string public title;
    string public authors;
    uint public timestamp;
    string public meta; // link to ipfs article Json - Affiliations, Abstract, searchable values etc...
    string public pdf; // link to ipfs article
    address public author;

    function Article(string _meta, string _pdf, string _title, string _authors) public {
        meta = _meta;
        pdf = _pdf;
        title = _title;
        authors = _authors;
        timestamp = now;
        author = msg.sender;
    }
}