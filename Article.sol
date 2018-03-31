pragma solidity ^0.4.19;

import "./ERC20.sol";
import "./Field.sol";

contract Article {
/************************************************************/
/*********************** public data ************************/
/************************************************************/
    TokenERC20 public _ScienceToken;
    
    bytes32[] public versions; //metaData
    mapping(bytes32 => bytes32[]) public additionalData; //pdf's for example
    mapping(bytes32 => bytes32[]) public reviews;

    mapping(bytes32 => address[]) public madeBy;
    mapping(bytes32 => address) public acceptedBy; //if it's 0, it's not approved
    mapping(bytes32 => address) public retractedBy;
    mapping(bytes32 => address) public rejectedBy;
    mapping(bytes32 => address) public punishedBy;
    mapping(bytes32 => uint) public createdOn;
    mapping(bytes32 => uint) public claimed;

    address[] public authors;
    mapping(address => bool) public isAdmin;

    bytes32[] public comments;
    
    uint public coAuthorBounty;
    uint public reviewBounty;
    uint public coAuthorClaim;
    uint public reviewClaim;
    
    Field public field;
    
/************************************************************/

/************************************************************/
/************************* modifiers ************************/
/************************************************************/
    modifier mainAuthorAccess {
        require(isAdmin[msg.sender]);
        _;
    }
    
    function virginLink(bytes32 _ipfsLink) private view returns (bool) {
        return (     acceptedBy[_ipfsLink] == address(0) &&
                    retractedBy[_ipfsLink] == address(0) &&
                    rejectedBy[_ipfsLink] == address(0) &&
                    punishedBy[_ipfsLink] == address(0)
        );
    }
    
    modifier creatorAccess(bytes32 _ipfsLink) {
        bool isAuthor = false;
        uint i = 0;
        while ((i < madeBy[_ipfsLink].length) && (!isAuthor)){
            isAuthor = (madeBy[_ipfsLink][i] == msg.sender);
            i++;
        }
        require(isAuthor);
        _;
    }
/************************************************************/

/************************************************************/
/***************** contract creation ************************/
/************************************************************/
    function Article(address _scienceToken, bytes32 _initialVersion, address[] _coAuthors, bytes32[] _additionalData, Field _field) public {
        //init Token
        _ScienceToken = TokenERC20(_scienceToken);
        field = _field;
        //init authors
        authors.push(msg.sender);
        isAdmin[msg.sender] = true;
        versions.push(_initialVersion);
        madeBy[_initialVersion].push(msg.sender);
        //init coauthors
        for(uint i = 0; i < _coAuthors.length; i++){
            authors.push(_coAuthors[i]);
            madeBy[_initialVersion].push(_coAuthors[i]);
        }
        //releaseVersion
        acceptedBy[_initialVersion] = msg.sender;
        createdOn[_initialVersion] = now;
        claimed[_initialVersion] = 0;
        //add aditional info
        for(i = 0; i < _additionalData.length; i++){
            additionalData[_initialVersion].push(_additionalData[i]);
        }
    }
/************************************************************/


/************************************************************/
/********* getters (for full arrays) ************************/
/************************************************************/
    function getVersions() public view returns (bytes32[]){
        return versions;
    }
    
    function getAdditionalData (bytes32 _version) public view returns (bytes32[]){
        return (additionalData[_version]);
    }
    
    function getReviews (bytes32 _version) public view returns (bytes32[]){
        return (reviews[_version]);
    }
    
    function getEntryData(bytes32 _ipfsLink) public view returns (address[], address, address, address, address, uint, uint){
        return (madeBy[_ipfsLink], acceptedBy[_ipfsLink], retractedBy[_ipfsLink], rejectedBy[_ipfsLink], punishedBy[_ipfsLink], createdOn[_ipfsLink], claimed[_ipfsLink]);
    }
    
    function getAuthors() public view returns (address[]){
        return (authors);
    }
/************************************************************/

/************************************************************/
/********* setters (main author access) *********************/
/************************************************************/
    //only possible to add? safer. allow also non-authors (for editors)
    function changeAuthorStatus(address _newAuthor) public mainAuthorAccess {
        isAdmin[_newAuthor] = true;
    }
    
    //rewards and punishments
    function setBounties(uint _coAuthorBounty, uint _reviewBounty, uint _coAuthorClaim, uint _reviewClaim) public mainAuthorAccess {
        coAuthorBounty = _coAuthorBounty;
        reviewBounty = _reviewBounty;
        coAuthorClaim = _coAuthorClaim;
        reviewClaim = _reviewClaim;
    }
    
    /********* private ******************************************/
    function reject(bytes32 _ipfsLink, bool _punish) private {
        require(virginLink(_ipfsLink));
        rejectedBy[_ipfsLink] = msg.sender;
        createdOn[_ipfsLink] = now;
        if (_punish){
            punishedBy[_ipfsLink] = msg.sender;
        }
        else{
            uint claim = claimed[_ipfsLink];
            claimed[_ipfsLink] = 0;
            _ScienceToken.transfer(madeBy[_ipfsLink][0], claim); //let them split it themselves
        }
    }
    function accept(bytes32 _ipfsLink, uint _bounty) private {
        require(virginLink(_ipfsLink));
        acceptedBy[_ipfsLink] = msg.sender;
        createdOn[_ipfsLink] = now;
        uint fullBounty = _bounty + claimed[_ipfsLink];
        claimed[_ipfsLink] = 0;
        _ScienceToken.transfer(madeBy[_ipfsLink][0], fullBounty); //let them split it themselves
    }
    /************************************************************/
    
    function acceptVersion(bytes32 _version) public mainAuthorAccess {
        accept(_version, coAuthorBounty);
        for(uint i = 0; i < madeBy[_version].length; i++){
            authors.push(madeBy[_version][i]);
        }
    }
    
    function rejectVersion(bytes32 _version, bool _punish) public mainAuthorAccess{
        reject(_version, _punish);
    }
    
    function approveReview(bytes32 _review) public mainAuthorAccess {
        accept(_review, reviewBounty);
    }
    
    function rejectReview(bytes32 _review, bool _punish) public mainAuthorAccess{
        reject(_review, _punish);
    }
/************************************************************/

/************************************************************/
/************ changers (creator access) *********************/
/************************************************************/
    function retractVersion(bytes32 _version) public creatorAccess(_version) {
        if (virginLink(_version)) //cancel
        {
            uint claim = claimed[_version];
            claimed[_version] = 0;
            _ScienceToken.transfer(madeBy[_version][0], claim);
        }
        retractedBy[_version] = msg.sender;
    }

/************************************************************/
/****************** add new *********************************/
/************************************************************/
    //you'll have to transfer tokens first to attach the data
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public { 
        require(_token == address(_ScienceToken));
        require(msg.sender == address(_ScienceToken));
        bytes32 ipfsLink;
        assembly 
        {
            ipfsLink := mload(0x80) //mem location of _extraData
        }
        _ScienceToken.transferFrom(_from, this, _value);
        claimed[ipfsLink] += _value;
    }
    
    function addVersion(bytes32 _version, address[] _coAuthors, bytes32[] _additionalData) public {
        require (claimed[_version] >= coAuthorClaim); //check that claim is made
        versions.push(_version);
        madeBy[_version].push(msg.sender);
        for(uint i = 0; i < _coAuthors.length; i++){
            madeBy[_version].push(_coAuthors[i]);
        }
        for(i = 0; i < _additionalData.length; i++){
            additionalData[_version].push(_additionalData[i]);
        }
    }
    
    function addReview(bytes32 _version, bytes32 _review, address[] _coReviewers) public {
        require (claimed[_review] >= reviewClaim); //check that claim is made
        reviews[_version].push(_review);
        madeBy[_review].push(msg.sender);
        for(uint i = 0; i < _coReviewers.length; i++){
            madeBy[_review].push(_coReviewers[i]);
        }
    }
    
    function addComment(bytes32 _comment) public {
        comments.push(_comment);
    }

/************************************************************/

/************************************************************/
/******************** close *********************************/
/************************************************************/
    function areThereUntouchedCommits () public view returns (bool) {
        bool virginCommits = false;
        uint i = 0;
        uint j = 0;
        while ((i < versions.length)&&(!virginCommits)) //in theoretical case of huge number of rewiews/versions the article will be "unclosable". this is OK.
        {
            virginCommits = virginLink(versions[i]);
            j = 0;
            while ((j < reviews[versions[i]].length)&&(!virginCommits))
            {
                virginCommits = virginLink(reviews[versions[i]][j]);
                j++;
            }
            i++;
        }
        return virginCommits;
    }

    function closeArticle () mainAuthorAccess public {
        //useless if the claims are 0
        require(!areThereUntouchedCommits());
        _ScienceToken.transfer(authors[0], _ScienceToken.balanceOf(this));  //this withdraws the pot and effectively closes the article untill someone pays to re-open it.
    }
}
